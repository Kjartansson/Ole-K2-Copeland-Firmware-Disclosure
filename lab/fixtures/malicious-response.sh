#!/bin/sh
printf 'HTTP/1.1 200 OK\r\nContent-Disposition: attachment; filename="x\";printf DOWNLOAD_CANARY>/opt/setup/templates/download-canary;#"\r\nContent-Length: 1\r\nConnection: close\r\n\r\nx'
