import asyncio
import io

import httpx
import respx

from lib.common.http import request_json


def test_request_json_rewinds_multipart_files_on_retry() -> None:
    async def run() -> None:
        payload = io.BytesIO(b"attachment-content")
        call_count = {"value": 0}
        body_lengths: list[int] = []

        def handler(request: httpx.Request) -> httpx.Response:
            call_count["value"] += 1
            body_lengths.append(len(request.content))
            if call_count["value"] == 1:
                return httpx.Response(500, text='{"error":"temporary"}')
            return httpx.Response(200, json={"ok": True})

        with respx.mock(assert_all_called=True) as router:
            router.post("https://api.example.com/upload").mock(side_effect=handler)

            result = await request_json(
                method="POST",
                url="https://api.example.com/upload",
                provider="TestProvider",
                auth_hint="Set TEST_TOKEN",
                files={"file": ("sample.txt", payload)},
                max_retries=1,
            )

            assert result["ok"] is True
            assert call_count["value"] == 2
            assert body_lengths[0] > 0
            assert body_lengths[1] > 0

    asyncio.run(run())
