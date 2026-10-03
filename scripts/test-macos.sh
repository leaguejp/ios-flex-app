#!/usr/bin/env bash
set -euo pipefail
mkdir -p build artifacts/tests
clang -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined core/encoding.c core/macho.c tests/core_test.c -o build/core-test
build/core-test | tee artifacts/tests/core.txt
clang -fblocks -fno-objc-arc -Wall -Wextra -Werror -c hook/LXHookEngine.m -o build/hooks.o
clang -std=c11 -c core/encoding.c -o build/encoding.o
clang -std=c11 -c core/macho.c -o build/macho.o
clang -fobjc-arc -fblocks -DLX_HOST_FIXTURE_TESTS=1 -Wall -Wextra -Werror tests/runtime_test.m testtarget/LXFixture.m runtime/LXScanner.m static/LXStaticAnalyzer.m shared/LXTypes.m shared/LXProtocol.m build/hooks.o build/encoding.o build/macho.o -framework Foundation -o build/runtime-test
build/runtime-test | tee artifacts/tests/runtime.txt
clang -fobjc-arc -fblocks -Wall -Wextra -Werror tests/ipc_test.m shared/LXChannel.m shared/LXProtocol.m shared/LXAuth.m -framework Foundation -o build/ipc-test
build/ipc-test | tee artifacts/tests/ipc.txt
python3 -m unittest discover -s tests -p 'test_*.py' -v 2>&1 | tee artifacts/tests/python.txt
