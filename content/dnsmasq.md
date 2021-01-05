http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html

dnsmasq 是基于线程的，如果 upstream DNS 服务器解析慢，会导致全部卡在那里。
需要设置 `--dns-forward-max=<queries>`。

