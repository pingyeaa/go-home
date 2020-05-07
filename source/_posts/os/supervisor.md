---
title: 进程管理工具 Supervisor
date: 2020-04-23 14:30:29
categories:
- 操作系统
tags:
- supervisor
- 进程
- 监控
---

> 我是平也，这有一个专注Gopher技术成长的开源项目[「go home」](https://github.com/pingyeaa/go-home)

要想在终端后台常驻进程，首先想到的是在命令后加 & 符号，来达到隐藏程序在后台的目的，尽管看起来进程已经在后台运行了，实际上终端会话关闭时进程还是会被 kill 掉，这种问题一般是采用搭配 nohup 命令来解决的，nohup 作用是忽略 SIGHUP 信号，而会话关闭时正好发送了该信号给会话内所有运行程序，简而言之，nohup 命令搭配 & 不仅可以在后台运行，还不受会话关闭的影响。

```shell
$ nohup /bin/cat &
```

![file](https://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1587648951163.png)

那么问题来了，虽然做到了后台运行，也避免了挂断操作带来的影响，但是它避免不了常驻进程自己出现问题，一旦它因自身异常终止了进程，这对黄金搭档就无力回天了。那怎么才能把挂了的常驻进程拉起来呢？这就是我们要讲的主题 Supervisor。

### Supervisor 介绍

Supervisor 是专门用来在[类 Unix](#unix) 系统上监控管理进程的工具，发布于 2004 年，虽然名字气势磅礴，但它的志向并不是统筹整个操作系统的进程，而是致力于做一个听话的贴身助理，你只需要告诉它要管理的程序，它就按你的要求监控进程，救死扶伤，保证进程的持续运行。

![file](https://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1587649424854.png)

<span id="unix"></span>

> 类 Unix 系统就是由 Unix 设计风格演变出的操作系统，除了 Windows 市面上绝大多数系统都是类 Unix 系统。

官方文档介绍 Supervisor 是 C/S 架构体系，它对应的角色分别为 Supervisorctl 和 Supervisord。后者的主要作用是启动配置好的程序、响应 Supervisorctl 发过来的指令以及重启退出的子进程，而前者是 Supervisor 的客户端，它以命令行的形式提供了一系列参数，来方便用户向 Supervisord 发送指令，常用的有启动、暂停、移除、更新等命令。

### Supervisor 安装与配置

安装 Supervisor 很简单，在各大操作系统的软件包管理器中都可以直接安装。

```shell
$ yum install -y supervisor
```

安装好的 Supervisor 配置文件默认为 /etc/supervisor.conf，如果找不到配置文件可以[通过官方命令生成](#gen_conf)，该配置文件包含了一个空的配置目录 /etc/supervisor.d（不同 OS 可能不一样），只需在该目录添加配置文件即可动态扩展，所以 supervisor.conf 一般不需要做改动。

我们以最简单的 cat 命令为例，cat 命令不加参数会阻塞住等待标准输入，所以很适合做常驻进程的演示。现在创建一个配置文件 cat.ini 到 /etc/supervisor.d/，第一行定义程序的名称，该名称用来做操作的标识，第二行定义命令路径，它才是程序执行的根本命令。

```shell /etc/supervisor.d/cat.ini
[program:foo]
command=/bin/cat
```

配置好后，启动 supervisord 服务，注意通过 -c 指定 supervisor 的配置文件。

```shell
$ supervisord -c /etc/supervisord.conf
```

当然也可以不指定配置路径，那么它会按以下顺序逐个搜索配置文件：

- $CWD/supervisord.conf
- $CWD/etc/supervisord.conf
- /etc/supervisord.conf
- /etc/supervisor/supervisord.conf
- ../etc/supervisord.conf
- ../supervisord.conf

<span id="gen_conf"></span>

如果你是通过 Mac OS 安装的 Supervisor，可能从上述目录都找不到配置文件，可以利用官方提供的命令生成配置。

```shell
$ echo_supervisord_conf > supervisor.conf
```

这个时候 cat 进程应该已经跑起来了。

```shell
$ ps aux | grep /bin/cat
```

杀掉进程，进程 id 会发生变化，证明 supervisor 又把 cat 拉了起来。

```shell
$ sudo kill 9 <进程ID>
```

### 核心配置讲解

配置文件中的选项并不止 command，官方提供了很多配置项。

```ini
[program:name]
command=sh /tmp/echo_time.sh
priority=999
numprocs=1
autostart=true
autorestart=true
startsecs=10
startretries=3 
exitcodes=0,2
stopsignal=QUIT
stopwaitsecs=10
user=root
log_stdout=true
log_stderr=true
logfile=/tmp/echo_time.log
logfile_maxbytes=1MB
logfile_backups=10 
stdout_logfile_maxbytes=20MB 
stdout_logfile_backups=20 
stdout_logfile=/tmp/echo_time.stdout.log
```

下面挑选几个配置简要说明

- command：要执行的命令
- priority：执行优先级，值越高就越晚启动，越早关闭
- numprocs：进程数量
- autostart：是否与 supervisord 一起启动
- autorestart：自动重启
- startsecs：延时启动时间，默认为 10 秒
- startretries：启动重试次数，默认为 3 次
- exitcodes：当程序的退出码为 0 或 2 时，重启
- stopsignal：停止信号
- stopwaitsecs：延时停止时间，收到停止指令后多久停止
- user：以哪个用户执行

### 动态操作子程序

添加新的程序，只需增加配置文件，然后执行 supervisorctl update 即可动态添加新的程序，并不需要重启 supervisord 服务。如果出现 refused connection 的提示，可能是没找到配置文件，需要加上配置选项。

```shell
$ supervisorctl update
foo1: added process group
```

删除同理，remove 时会先将进程关闭，再从列表中移除。

```shell
foo1: stopped
foo1: removed process group
```

如果需要单独停止某个程序，可以使用 stop 命令，stop 后跟的是 program 名称。

```shell
$ supervisorctl stop foo
foo: stopped
```

当然还可以通过 stop all 命令更加暴力的停止所有进程。

```shell
$ supervisorctl stop all
foo: stopped
foo1: stopped
```

反之亦然，启动进程只需要将 stop 改为 start。

```shell
$ supervisorctl start all
```

#### 连接到某个进程

```shell
$ supervisorctl fg <program 名称>
```

#### 重启 supervisord

```shell
$ supervisorctl reload
```

#### 动态加载 supervisor.conf

```shell
$ supervisorctl reread
```

#### 查看所有进程运行状况

```shell
$ supervisorctl status
```

### Web 界面操作

官方提供了界面操作方式，需要在 supervisor.conf 中去掉 inet_http_server 的注释。

```ini supervisor.conf
[inet_http_server]         ; inet (TCP) server disabled by default
port=127.0.0.1:9001        ; ip_address:port specifier, *:port for all iface
username=user              ; default is no username (open server)
password=123               ; default is no password (open server)
```

重启 supervisord。

```shell
$ supervisorctl reload
```

访问 http://localhost:9001 可以看到 supervisor 的操作界面。

![file](https://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1587696070630.png)

今天文章就到这里，想要了解更多，欢迎查看[官方文档](http://supervisord.org/)。