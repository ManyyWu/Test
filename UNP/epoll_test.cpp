#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/types.h>
#include <sys/errno.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <arpa/inet.h>

#define SERVER_ADDR "192.168.0.2"
#define SERVER_PORT 20000
#define BUF_SIZE    4096
#define EPOLL_MAX   100

void
log_exit (const char *err_str)
{
    errno ? fprintf(stderr, "LOGERR: %s: %s\n", err_str, strerror(errno))
          : fprintf(stderr, "LOGERROR: %s\n", err_str);
    exit(errno);
}

#pragma pack(push, 1)
struct head_t {
    uint32_t len;
};
struct msg_t {
    struct head_t _head;
    uint8_t *     _data;
};
#pragma pack(pop)

int create_and_bind (const char *_addr, uint16_t _port)
{
    /* create socket */
    int listen_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (listen_fd < 0) {
        fprintf(stderr, "socket() error\n");
        return -1;
    }

    /* init address struct */
    struct sockaddr_in sa;
    bzero(&sa, sizeof(sockaddr_in));
    sa.sin_family = AF_INET;
    sa.sin_port = htons(_port);
    sa.sin_addr.s_addr = inet_addr(_addr);

    /* bind */
    int ret = bind(listen_fd, (sockaddr *)&sa, sizeof(sa));
    if (ret < 0) {
        fprintf(stderr, "bind() error\n");
        close(listen_fd);
        return -1;
    }

    return listen_fd;
}

int set_nonblocking (int _fd)
{
    int flags = fcntl(_fd, F_GETFL, 0);
    if (flags < 0)
        return -1;
    if (fcntl(_fd, F_SETFL, flags | O_NONBLOCK) < 0)
        return -1;
    return 0;
}

int
server_test ()
{
    int         ret = 0;
    int         epfd = -1;
    int         optval;
    epoll_event es[EPOLL_MAX];
    epoll_event e;

    /* create and bind */
    int listen_fd = create_and_bind(SERVER_ADDR, SERVER_PORT);
    if (ret < 0)
        log_exit("create_and_bind() error");

    /* set nonblocking */
    ret = set_nonblocking(listen_fd);
    if (ret < 0) {
        fprintf(stderr, "set_nonblocking() error\n");
        goto fail;
    }

    /* listen */
    ret = listen(listen_fd, 5);
    if (ret < 0) {
        fprintf(stderr, "listen() error!\n");
        goto fail;
    }

    /* create epoll */
    epfd = epoll_create(EPOLL_MAX);
    if (epfd < 0) {
        fprintf(stderr, "epoll_create() error\n");
        goto fail;
    }

    /* add listen_fd for listen */
    e.data.fd = listen_fd;
    e.events = EPOLLIN;
    ret = epoll_ctl(epfd, EPOLL_CTL_ADD, listen_fd, &e);
    if (ret < 0) {
        fprintf(stderr, "epoll_ctl() error\n");
        goto fail;
    }

    while (true) { /////////////////////////////
        int n= epoll_wait(epfd, es, EPOLL_MAX, -1);
        if (n < 0) {
            fprintf(stderr, "epoll_wait() error\n");
            goto fail;
        }
        for (int i = 0; i < n; i++) {
            if (es[i].events & (EPOLLERR | EPOLLHUP)) {
                e.data.fd = es[i].data.fd;
                e.events = EPOLLIN;
                epoll_ctl(epfd, EPOLL_CTL_DEL, es[i].data.fd, &e);
                close(es[i].data.fd);
                fprintf(stderr, "fd %d error or hup\n", es[i].data.fd);
                continue;
            }
            if (es[i].events & EPOLLIN) {
                if (es[i].data.fd == listen_fd) { // listen fd
                    // new connection
                    do {
                        struct sockaddr_in sa;
                        socklen_t len = sizeof(sockaddr_in);
                        int newfd = accept(listen_fd, (sockaddr*)&sa, &len);
                        if (newfd < 0) {
                            if (EAGAIN == errno || EWOULDBLOCK == errno)
                                ;
                            else
                                fprintf(stderr, "accept() error: %s\n", strerror(errno));
                            break;
                        }
                        fprintf(stderr, "new connection from %s:%d\n",
                                inet_ntoa(sa.sin_addr), sa.sin_port);

                        /* set nonblocking */
                        ret = set_nonblocking(newfd);
                        if (ret < 0) {
                            fprintf(stderr, "set_nonblocking() error\n");
                            close(newfd);
                            break;
                        }

                        /* register event */
                        e.data.fd = newfd;
                        e.events = EPOLLIN;
                        ret = epoll_ctl(epfd, EPOLL_CTL_ADD, newfd, &e);
                        if (ret < 0) {
                            fprintf(stderr, "epoll_ctl() error");
                            close(newfd);
                            break;
                        }
                    } while (false);
                } else { // client fd
                    // data from client
                    char buf[BUF_SIZE];
                    struct sockaddr_in sa;

                    int sock_len = sizeof(sockaddr_in);
                    int a = getpeername(es[i].data.fd, (sockaddr *)&sa, (socklen_t *)&sock_len);
                    // read data from client
                    ret = read(es[i].data.fd, buf, BUF_SIZE);
                    if (ret <= 0) {
                        e.data.fd = es[i].data.fd;
                        e.events = EPOLLIN;
                        epoll_ctl(epfd, EPOLL_CTL_DEL, es[i].data.fd, &e);
                        close(es[i].data.fd);
                        if (!ret) {
                            fprintf(stderr, "LOGERR: read error@%s\n", strerror(errno));
                        } else { // connection closed
                            fprintf(stderr, "LOGINFO: connnection [%s: %d] closed\n",
                                    inet_ntoa(sa.sin_addr), ntohs(sa.sin_port));
                        }
                        continue;
                    }
                    fprintf(stderr, "[%s: %d] - %s\n",
                            inet_ntoa(sa.sin_addr), ntohs(sa.sin_port), buf);
                    buf[0] = '\0';

                    // response client
                    *(int *)buf = ret;
                    ret = write(es[i].data.fd, buf, 4);
                    if (ret != 4) {
                        e.data.fd = es[i].data.fd;
                        e.events = EPOLLIN;
                        epoll_ctl(epfd, EPOLL_CTL_DEL, es[i].data.fd, &e);
                        close(es[i].data.fd);
                        if (ret) {
                            fprintf(stderr, "LOGERR: write error@%s\n", strerror(errno));
                        } else { // connection closed
                            fprintf(stderr, "LOGINFO: connnection [%s: %d] closed\n",
                                   inet_ntoa(sa.sin_addr), ntohs(sa.sin_port));
                        }
                        continue;
                    }
                }
            }
        }
    }

fail:
    if (listen_fd >= 0)
        close(listen_fd);
    listen_fd = 0;
    if (epfd >= 0)
        close(epfd);
    epfd = 0;
    return 0;
}

int
client_test ()
{
    int         server_fd;
    sockaddr_in server_addr;
    ssize_t     ret;
    char        buf[BUF_SIZE];
    fd_set      rset;
    int         maxfdp1;

    /* create server socket */
    server_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (server_fd < 0)
        log_exit("LOGERR: create socket error");

    /* init server address */
    bzero(&server_addr, sizeof(sockaddr_in));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(SERVER_PORT);
    ret = inet_aton(SERVER_ADDR, &server_addr.sin_addr);
    if (ret < 0) {
        close(server_fd);
        log_exit("LOGERR: invalid address");
    }

    /* connect to server */
    fprintf(stderr, "LOGINFO: connecting to server [%s: %d]\n", SERVER_ADDR, SERVER_PORT);
    ret = connect(server_fd, (sockaddr *)&server_addr, sizeof(sockaddr_in));
    if (ret < 0) {
        close(server_fd);
        log_exit("LOGERR: failed to connect to server");
    }
    fprintf(stderr, "LOGINFO: connected to server [%s: %d]\n", SERVER_ADDR, SERVER_PORT);

    while (true) {
        /* select */
        FD_ZERO(&rset);
        FD_SET(fileno(stdin), &rset);
        FD_SET(server_fd, &rset);
        maxfdp1 = (fileno(stdin) > server_fd ? fileno(stdin) : server_fd) + 1;
        ret = select (maxfdp1, &rset, NULL, NULL, NULL);
        if (ret < 0) {
            fprintf(stderr, "LOGERR: select error@%s\n", strerror(errno));
            break;
        }

        if (FD_ISSET(fileno(stdin), &rset)) {
            /* read */
            ret = fscanf(stdin, "%s", buf);
            if (ret <= 0) {
                if (ret)
                    fprintf(stderr, "LOGINFO: EOF\n");
                else
                    fprintf(stderr, "LOGERR: read error@%s\n", strerror(errno));
                break;
            }
            buf[BUF_SIZE - 1] = 0;

            /* send data to server */
            ret = write(server_fd, buf, (size_t)strlen(buf) + 1);
            if (ret < 0) {
                fprintf(stderr, "LOGERR: write error@%s\n", strerror(errno));
                break;
            }
        }

        //if (FD_ISSET(server_fd, &rset)) {
        //    /* read data from server */
        //    ret = read(server_fd, buf, 4);
        //    if (ret < 0) {
        //        fprintf(stderr, "LOGERR: read error@%s\n", strerror(errno));
        //    } else if (ret) {
        //        fprintf(stderr, "Server read %d bytes\n", *(int *)buf);
        //        continue;
        //    } else { // closed
        //        break;
        //    }
        //    break;
        //}
    }

    /* close socket */
    close(server_fd);
    fprintf(stderr, "LOGINFO: connection closed\n");

    return 0;
}

int
main (int argc, char **argv)
{
    if (2 != argc)
        log_exit("params error!\n");

    int opt = getopt(argc, argv, "cs");
    switch (opt) {
        case 'c':
            client_test();
            break;
        case 's':
            server_test();
            break;
        case '?':
        default:
            log_exit("invalid param");
    }

    putchar('\n');
    return 0;
}
