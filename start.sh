#!/bin/sh
NPROC=`grep -c ^processor /proc/cpuinfo 2>/dev/null || 1`
ulimit -n 200000
cat <<EOF > /opt/openresty/nginx/conf/nginx.conf
worker_processes $NPROC;
daemon off;

events {
	worker_connections  200000; 
	use epoll;
	multi_accept on;
}

worker_rlimit_nofile 200000;
error_log	logs/error.log;

http {
	init_by_lua_block {
	        -- use resty.core for performance improvement, see the status note above
	        require "resty.core"

		-- require the base module
	        local lua_resty_waf = require "resty.waf"

		-- perform some preloading and optimization
	        lua_resty_waf.init()
    	}

	# Caches information about open FDs, freqently accessed files.
	# Changing this setting, in my environment, brought performance up from 560k req/sec, to 904k req/sec.
	# I recommend using some varient of these options, though not the specific values listed below.
	open_file_cache max=200000 inactive=20s;
	open_file_cache_valid 30s;
	open_file_cache_min_uses 2;
	open_file_cache_errors on;

	# Sendfile copies data between one FD and other from within the kernel.
	# More efficient than read() + write(), since the requires transferring data to and from the user space.
	sendfile on;

	# Tcp_nopush causes nginx to attempt to send its HTTP response head in one packet,
	# instead of using partial frames. This is useful for prepending headers before calling sendfile,
	# or for throughput optimization.
	tcp_nopush on;

	# don't buffer data-sends (disable Nagle algorithm). Good for sending frequent small bursts of data in real time.
	tcp_nodelay on;

	# Timeout for keep-alive connections. Server will close connections after this time.
	keepalive_timeout 30;

	# Number of requests a client can make over the keep-alive connection. This is set high for testing.
	keepalive_requests 100000;

	# allow the server to close the connection after a client stops responding. Frees up socket-associated memory.
	reset_timedout_connection on;

	# send the client a "request timed out" if the body is not loaded by this time. Default 60.
	client_body_timeout 10;

	# If the client stops reading data, free up the stale client connection after this much time. Default 60.
	send_timeout 2;

	# Compression. Reduces the amount of data that needs to be transferred over the network
	gzip on;
	gzip_min_length 10240;
	gzip_proxied expired no-cache no-store private auth;
	gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml;
	gzip_disable "MSIE [1-6]\.";

    	include       mime.types;
    	default_type  application/octet-stream;

    	client_body_buffer_size     10K;
    	client_header_buffer_size    8k;
    	client_max_body_size          0;
    	large_client_header_buffers 4 16k;

    	log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
    	'\$status $body_bytes_sent "\$http_referer" '
    	'"\$http_user_agent" "\$http_x_forwarded_for"';

    	lua_package_path   "/opt/openresty/lualib/?.lua;;";
	access_log	   logs/access.log main buffer=16k;

    	include /opt/openresty/nginx/conf/sites/*.conf;

}
EOF

/opt/openresty/nginx/sbin/nginx
