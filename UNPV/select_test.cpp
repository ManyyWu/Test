/*
 * select() test
 * */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <getopt.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#include <sys/errno.h>
#include <sys/select.h>
#include <time.h>

const int    MAX_CONN    = 10;
const int    BUF_SIZE    = 8192;
const short  SERVER_PORT = 20000;
const char * SERVER_ADDR = "192.168.0.2";

void
err_exit (const char *err_str)
{
    errno ? printf("LOGERR: %s@%s\n", err_str, strerror(errno)) : printf("LOGERROR: %s\n", err_str);
    fflush(stdout);
    exit(errno);
}

void sig_pipe (int signo)
{
    if (signo == SIGPIPE) {
        printf("SIGPIPE\n");
        fflush(stdout);
    }
    return;
}

int
server_test ()
{
    int         listen_fd;
    sockaddr_in listen_addr;
    sockaddr_in client_addr;
    int         sock_len;
    ssize_t     ret;
    char        buf[BUF_SIZE];
    int         clientfd[MAX_CONN];
    int         newconnfd;
    fd_set      rset;
    int         maxfdp1;
    int         conn_num = 0;

    /* create listen socket */
    listen_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (listen_fd < 0)
        err_exit("create socket error");

    /* init listen address */
    bzero(&listen_addr, sizeof(sockaddr_in));
    listen_addr.sin_family = AF_INET;
    listen_addr.sin_port = htons(SERVER_PORT);
    listen_addr.sin_addr.s_addr = htonl(INADDR_ANY);

    /* bind */
    ret = bind(listen_fd, (sockaddr *)&listen_addr, sizeof(sockaddr_in));
    if (ret < 0) {
        close(listen_fd);
        err_exit("bind error");
    }

    /* listen */
    ret = listen(listen_fd, MAX_CONN);
    if (ret < 0) {
        close(listen_fd);
        err_exit("listen error");
    }

    FD_ZERO(&rset);
    for (int i = 0; i < MAX_CONN; i++)
        clientfd[i] = -1;
    maxfdp1 = listen_fd;
    while (true) {
        /* select */
        FD_ZERO(&rset);
        for (int i = 0; i < MAX_CONN; i++)
            if (-1 != clientfd[i])
                FD_SET(clientfd[i], &rset);
        FD_SET(listen_fd, &rset);
        ret = select(maxfdp1 + 1, &rset, NULL, NULL, NULL);
        if (ret < 0) {
            printf("LOGERR: select error@%s\n", strerror(errno));
            fflush(stdout);
            break;
        }

        if (FD_ISSET(listen_fd, &rset)) { // new connection from client
            /* accept */
            bzero(&client_addr, sizeof(sockaddr_in));
            sock_len = sizeof(sockaddr_in);
            newconnfd = accept(listen_fd, (sockaddr *)&client_addr, (socklen_t *)&sock_len);
            if (newconnfd < 0) {
                printf("LOGERR: accept error@%s\n", strerror(errno));
                fflush(stdout);
                break;
            }
            if (conn_num == MAX_CONN) { // too more client
                close(newconnfd);
                printf("LOGWARNING: too many client, new connnection [%s: %d] has been refused\n",
                       inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port));
                continue;
            }

            /* save fd */
            conn_num++;
            for (int i = 0; i < MAX_CONN; i++) {
                if (-1 == clientfd[i]) {
                    clientfd[i] = newconnfd;
                    break;
                }
            }
            maxfdp1 = maxfdp1 < newconnfd ? newconnfd : maxfdp1;
            printf("LOGINFO: new connection from [%s: %d]\n",
                   inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port));
        }

        if (ret > 0) {
            for (int i = 0; i < maxfdp1; i++) {
                maxfdp1 = maxfdp1 < clientfd[i] ? clientfd[i] : maxfdp1;
                if (clientfd[i] >= 0 && FD_ISSET(clientfd[i], &rset)) { // read ready
                    sock_len = sizeof(sockaddr_in);
                    int a = getpeername(clientfd[i], (sockaddr *)&client_addr, (socklen_t *)&sock_len);
                    // read data from client
                    ret = read(clientfd[i], buf, BUF_SIZE);
                    if (ret <= 0) {
                        close(clientfd[i]);
                        clientfd[i] = -1;
                        if (ret) {
                            printf("LOGERR: read error@%s\n", strerror(errno));
                        } else { // connection closed
                            printf("LOGINFO: connnection [%s: %d] closed\n",
                                   inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port));
                        }
                        conn_num--;
                        fflush(stdout);
                        continue;
                    }
                    printf("[%s: %d] - %s\n",
                           inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port), buf);
                    fflush(stdout);

                    // response client
                    *(int *)buf = ret;
                    ret = write(clientfd[i], buf, 4);
                    if (ret != 4) {
                        close(clientfd[i]);
                        clientfd[i] = -1;
                        if (ret) {
                            printf("LOGERR: write error@%s\n", strerror(errno));
                        } else { // connection closed
                            printf("LOGINFO: connnection [%s: %d] closed\n",
                                   inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port));
                        }
                        conn_num--;
                        fflush(stdout);
                        continue;
                    }
                }
            }
        }
    }
    for (int i = 0; i < MAX_CONN; i++)
        if (-1 != clientfd[i])
            close(clientfd[i]);
    printf("LOGINFO: all connection closed\n");

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
        err_exit("LOGERR: create socket error");

    /* init server address */
    bzero(&server_addr, sizeof(sockaddr_in));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(SERVER_PORT);
    ret = inet_aton(SERVER_ADDR, &server_addr.sin_addr);
    if (ret < 0) {
        close(server_fd);
        err_exit("LOGERR: invalid address");
    }

    /* connect to server */
    ret = connect(server_fd, (sockaddr *)&server_addr, sizeof(sockaddr_in));
    if (ret < 0) {
        close(server_fd);
        err_exit("LOGERR: failed to connect to server");
    }
    printf("LOGINFO: connected to server [%s: %d]\n", SERVER_ADDR, SERVER_PORT);
    fflush(stdout);

    while (true) {
        /* select */
        FD_ZERO(&rset);
        FD_SET(fileno(stdin), &rset);
        FD_SET(server_fd, &rset);
        maxfdp1 = (fileno(stdin) > server_fd ? fileno(stdin) : server_fd) + 1;
        ret = select (maxfdp1, &rset, NULL, NULL, NULL);
        if (ret < 0) {
            printf("LOGERR: select error@%s\n", strerror(errno));
            fflush(stdout);
            break;
        }

        if (FD_ISSET(fileno(stdin), &rset)) {
            /* read */
            ret = fscanf(stdin, "%s", buf);
            if (ret <= 0) {
                if (feof(stdin))
                    printf("LOGINFO: EOF\n");
                else
                    printf("LOGERR: read error@%s\n", strerror(errno));
                fflush(stdout);
                break;
            }
            buf[BUF_SIZE - 1] = 0;

            /* send data to server */
            ret = write(server_fd, buf, (size_t)strlen(buf) + 1);
            if (ret < 0) {
                printf("LOGERR: write error@%s\n", strerror(errno));
                fflush(stdout);
                break;
            }
        }

        if (FD_ISSET(server_fd, &rset)) {
            /* read data from server */
            ret = read(server_fd, buf, 4);
            if (ret < 0) {
                printf("LOGERR: read error@%s\n", strerror(errno));
            } else if (ret) {
                printf("Server read %d bytes\n", *(int *)buf);
                fflush(stdout);
                continue;
            } else { // closed
                break;
            }
            fflush(stdout);
            break;
        }
    }

    /* close socket */
    close(server_fd);
    printf("LOGINFO: connection closed\n");

    return 0;
}

int main (int argc, char **argv)
{
    if (2 != argc)
        err_exit("params error!\n");

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
        err_exit("invalid param");
    }

    putchar('\n');
    return 0;
}
