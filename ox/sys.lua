-- ox.sys
--
-- David Hollander 2011 MIT License
-- C headers in use by the Ox server library
--
-- Header strings forked from ljsyscall by Justin Cormack
-- See http://github.com/justincormack/ljsyscall for more headers
local ffi = require "ffi"
-- TYPES
--
ffi.cdef[[
// 16 bit
typedef uint16_t in_port_t;
// 32 bit
typedef uint32_t mode_t;
typedef uint32_t uid_t;
typedef uint32_t gid_t;
typedef uint32_t socklen_t;
typedef uint32_t id_t;
typedef int32_t pid_t;
typedef int32_t clockid_t;
// 64 bit
typedef uint64_t dev_t;
typedef uint64_t loff_t;
typedef uint64_t off64_t;
// posix standards
typedef unsigned short int sa_family_t;
// typedefs which are word length
typedef unsigned long size_t;
typedef long ssize_t;
typedef long off_t;
typedef long kernel_off_t;
typedef long time_t;
typedef long blksize_t;
typedef long blkcnt_t;
typedef long clock_t;
typedef unsigned long ino_t;
typedef unsigned long nlink_t;
typedef unsigned long rlim_t;
typedef unsigned long aio_context_t;
typedef unsigned long nfds_t;

]]
-- STRUCTS
--
ffi.cdef [[
struct pollfd {
  int fd;
  short int events;
  short int revents;
};
struct sockaddr {
  sa_family_t sa_family;
  char sa_data[14];
};
struct sockaddr_storage {
  sa_family_t ss_family;
  unsigned long int __ss_align;
  char __ss_padding[128 - 2 * sizeof(unsigned long int)]; /* total length 128 */
};
struct in_addr {
  uint32_t       s_addr;
};
struct in6_addr {
  unsigned char  s6_addr[16];
};
struct sockaddr_in {
  sa_family_t    sin_family;
  in_port_t      sin_port;
  struct in_addr sin_addr;
  unsigned char  sin_zero[8]; /* padding, should not vary by arch */
};
struct sockaddr_in6 {
  sa_family_t    sin6_family;
  in_port_t sin6_port;
  uint32_t sin6_flowinfo;
  struct in6_addr sin6_addr;
  uint32_t sin6_scope_id;
};
struct sockaddr_un {
  sa_family_t sun_family;
  char        sun_path[108];
};
struct sockaddr_nl {
  sa_family_t     nl_family;
  unsigned short  nl_pad;
  uint32_t        nl_pid;
  uint32_t        nl_groups;
};
struct addrinfo {
  int ai_flags;
  int ai_family;
  int ai_socktype;
  int ai_protocol;
  size_t ai_addrlen;
  struct sockaddr *ai_addr;
  char *ai_canonname;
  struct addrinfo *ai_next;
};
]]

-- FUNCTIONS
--
ffi.cdef[[
int open(const char *pathname, int flags);
int close(int fd);
ssize_t read(int fd, void *buf, size_t count);
ssize_t write(int fd, const void *buf, size_t count);
int inet_aton(const char *cp, struct in_addr *inp);
ssize_t send(int sockfd, const void *buf, size_t len, int flags);
ssize_t sendto(int sockfd, const void *buf, size_t len, int flags, const struct sockaddr *dest_addr, socklen_t addrlen);
ssize_t sendmsg(int sockfd, const struct msghdr *msg, int flags);
ssize_t recv(int sockfd, void *buf, size_t len, int flags);
ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags, struct sockaddr *src_addr, socklen_t *addrlen);
ssize_t recvmsg(int sockfd, struct msghdr *msg, int flags);
int getsockopt(int sockfd, int level, int optname, void *optval, socklen_t *optlen);
int setsockopt(int sockfd, int level, int optname, const void *optval, socklen_t optlen);

int poll(struct pollfd *fds, nfds_t nfds, int timeout);
ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);

int socket(int domain, int type, int protocol);
int socketpair(int domain, int type, int protocol, int sv[2]);
int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
int listen(int sockfd, int backlog);
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
int accept4(int sockfd, struct sockaddr *addr, socklen_t *addrlen, int flags);

int getsockname(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
int getpeername(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
int getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
]]


-- CONSTANTS
--
local typeof = ffi.typeof
local octal = function (s) return tonumber(s, 8) end
local bit = require'bit'
local S = {}
S.O_ACCMODE   = octal('0003')
S.O_RDONLY    = octal('00')
S.O_WRONLY    = octal('01')
S.O_RDWR      = octal('02')
S.O_CREAT     = octal('0100')
S.O_EXCL      = octal('0200')
S.O_NOCTTY    = octal('0400')
S.O_TRUNC     = octal('01000')
S.O_APPEND    = octal('02000')
S.O_NONBLOCK  = octal('04000')
S.O_NDELAY    = S.O_NONBLOCK
S.O_SYNC      = octal('04010000')
S.O_FSYNC     = S.O_SYNC
S.O_ASYNC     = octal('020000')
S.O_CLOEXEC   = octal('02000000')
S.O_NOATIME   = octal('01000000')
S.O_DSYNC     = octal('010000')
S.O_RSYNC     = S.O_SYNC

S.AF_INET         = 2
S.AF_INET6        = 10
S.SOCK_STREAM     = 1
S.SOCK_DGRAM      = 2
S.SOCK_RAW        = 3
S.SOCK_RDM        = 4
S.SOCK_SEQPACKET  = 5
S.SOCK_DCCP       = 6
S.SOCK_PACKET     = 10

S.SOL_SOCKET = 1
S.SO_REUSEADDR = 2

-- poll
S.POLLIN          = 0x001
S.POLLPRI         = 0x002
S.POLLOUT         = 0x004
S.POLLRDNORM      = 0x040
S.POLLRDBAND      = 0x080
S.POLLWRNORM      = 0x100
S.POLLWRBAND      = 0x200
S.POLLMSG         = 0x400
S.POLLREMOVE      = 0x1000
S.POLLRDHUP       = 0x2000
S.POLLERR         = 0x008
S.POLLHUP         = 0x010
S.POLLNVAL        = 0x020

-- inotify
-- flags
S.IN_CLOEXEC = octal("02000000")
S.IN_NONBLOCK = octal("04000")

-- events
S.IN_ACCESS        = 0x00000001
S.IN_MODIFY        = 0x00000002
S.IN_ATTRIB        = 0x00000004
S.IN_CLOSE_WRITE   = 0x00000008
S.IN_CLOSE_NOWRITE = 0x00000010
S.IN_OPEN          = 0x00000020
S.IN_MOVED_FROM    = 0x00000040
S.IN_MOVED_TO      = 0x00000080
S.IN_CREATE        = 0x00000100
S.IN_DELETE        = 0x00000200
S.IN_DELETE_SELF   = 0x00000400
S.IN_MOVE_SELF     = 0x00000800

S.IN_UNMOUNT       = 0x00002000
S.IN_Q_OVERFLOW    = 0x00004000
S.IN_IGNORED       = 0x00008000

S.IN_CLOSE         = S.IN_CLOSE_WRITE + S.IN_CLOSE_NOWRITE
S.IN_MOVE          = S.IN_MOVED_FROM + S.IN_MOVED_TO

S.IN_ONLYDIR       = 0x01000000
S.IN_DONT_FOLLOW   = 0x02000000
S.IN_EXCL_UNLINK   = 0x04000000
S.IN_MASK_ADD      = 0x20000000
S.IN_ISDIR         = 0x40000000
S.IN_ONESHOT       = 0x80000000

S.EAGAIN         = 11

S.IN_ALL_EVENTS    = S.IN_ACCESS + S.IN_MODIFY + S.IN_ATTRIB + S.IN_CLOSE_WRITE
                       + S.IN_CLOSE_NOWRITE + S.IN_OPEN + S.IN_MOVED_FROM
                       + S.IN_MOVED_TO + S.IN_CREATE + S.IN_DELETE
                       + S.IN_DELETE_SELF + S.IN_MOVE_SELF


S.sockaddr_t = typeof("struct sockaddr")
S.sockaddr_storage_t = typeof("struct sockaddr_storage")
S.sa_family_t = typeof("sa_family_t")
S.sockaddr_in_t = typeof("struct sockaddr_in")
S.sockaddr_in6_t = typeof("struct sockaddr_in6")
S.in_addr_t = typeof("struct in_addr")
S.in6_addr_t = typeof("struct in6_addr")
S.sockaddr_un_t = typeof("struct sockaddr_un")
S.sockaddr_nl_t = typeof("struct sockaddr_nl")
S.pollfds_t = typeof("struct pollfd [?]")
S.pollfd_pt = typeof("struct pollfd *")
S.int1_t = typeof("int[1]")

S.buffer_t = typeof("char[?]")

--return setmetatable({}, {__index=function(t,k) return S[k] or C[k] end})
return S
