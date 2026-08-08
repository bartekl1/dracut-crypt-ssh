#!/bin/bash
check() { return 0; }
depends() { return 0; }
install() {
    grep -q '^/bin/sh$' "${initdir}/etc/shells" 2>/dev/null || echo "/bin/sh" >> "${initdir}/etc/shells"
    sed -i 's#^root:.*#root:x:0:0:root:/root:/bin/sh#' "${initdir}/etc/passwd"
}
