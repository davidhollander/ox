-- DNS
--

-- potentially a global daemon in future, to prevent multiple threads\processes from calling getaddrinfo on the same address.
local dns = {}
local cache = {}

function dns.resolve(host)
end

function dns.bad(host, ip)
end
