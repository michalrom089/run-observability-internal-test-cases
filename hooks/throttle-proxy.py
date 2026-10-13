#!/usr/bin/env python3
# Usage: python3 ../hooks/throttle-proxy.py <port> <bytes_per_second> <ready_file>
#
# An HTTPS proxy on 127.0.0.1 that sends at most <bytes_per_second> to the
# client on each connection. hooks/throttle.sh starts it, so tofu init
# downloads the providers slowly. It touches <ready_file> once it listens.
#
# It reads the tunnel in chunks and sleeps after each one. It does not read
# the TLS traffic.
import asyncio
import pathlib
import sys

CHUNK_BYTES = 16 * 1024


async def pipe(reader, writer, bytes_per_second=None):
    try:
        while chunk := await reader.read(CHUNK_BYTES):
            writer.write(chunk)
            await writer.drain()
            if bytes_per_second:
                await asyncio.sleep(len(chunk) / bytes_per_second)
    except (ConnectionError, asyncio.IncompleteReadError):
        pass
    finally:
        writer.close()


async def handle(client_reader, client_writer, bytes_per_second):
    # The client opens a tunnel: CONNECT host:port HTTP/1.1, headers, a blank line.
    request = await client_reader.readuntil(b"\r\n\r\n")
    method, target, _ = request.split(b"\r\n", 1)[0].decode().split(" ", 2)
    if method != "CONNECT":
        client_writer.write(b"HTTP/1.1 405 Method Not Allowed\r\n\r\n")
        client_writer.close()
        return

    host, port = target.rsplit(":", 1)
    try:
        upstream_reader, upstream_writer = await asyncio.open_connection(host, int(port))
    except OSError:
        client_writer.write(b"HTTP/1.1 502 Bad Gateway\r\n\r\n")
        client_writer.close()
        return

    client_writer.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
    await client_writer.drain()

    await asyncio.gather(
        pipe(client_reader, upstream_writer),
        pipe(upstream_reader, client_writer, bytes_per_second),
    )


async def main(port, bytes_per_second, ready_file):
    server = await asyncio.start_server(
        lambda reader, writer: handle(reader, writer, bytes_per_second),
        "127.0.0.1",
        port,
    )
    pathlib.Path(ready_file).touch()
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]))
