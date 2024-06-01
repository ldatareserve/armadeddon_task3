#!/bin/bash

apt-get update
apt-get install -y apache2

cat <<EOT > /var/www/html/index.html
<html>
  <head>
    <title>Welcome to Europe Instance</title>
  </head>
  <body>
    <h1>Welcome to Europe Instance!</h1>
    <p>This page is served by Apache on a Google Compute Engine VM instance in Europe.</p>
  </body>
</html>
EOF