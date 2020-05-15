---
title: 如何使用 frp 实现内网穿透
date: 2020-05-13 20:19:38
tags:
- frp
- 内网穿透
- golang
categories:
- 网络
---

## 背景

作为一名程序员，家里多多少少会有一些落了灰的电脑，如果把闲置的电脑变成服务器，不仅有良好的配置，还能用来做各种测试，那就再好不过了。但是局域网的设备怎么被外网访问呢？这就靠内网穿透来实现了。

内网穿透又叫 [NAT](#nat) 穿透，常用的工具有很多，比如 ngrok、花生壳、frp等，因为我使用的是 frp，这也是本篇文章的主题。

<span id="nat"></span>

> NAT 是在 IP 数据包通过路由器或防火墙的时候重写 IP 地址的技术。因为现在的公网 IP 数量有限，国家不能给每个设备分配一个公网 IP，所以只能多台计算机共用一个公网 IP 对外通讯，这样就需要进行网络转换，而 NAT 的目的正是如此。

## 基本实现原理

frp 分为服务端与客户端，前者运行在有公网 IP 的服务器上，后者运行在局域网内的设备上，服务端默认会先开放 7000 端口，然后客户端与其相连。

![](https://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1589543547681.png)

同时客户端可以开启用于 ssh 的端口，与服务端的某个端口做映射，这样我们在终端访问服务端的端口时，会自动转发到客户端去。

![](https://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1589544730493.png)

除了 ssh 端口之外，frp 还支持 web 端口来接收 http 访问。

## 安装使用

目前需要公网服务器、内网服务器各一台，我的内网服务器重装了 linux 系统，方便试验各类工具。

### 服务端安装配置

```shell
wget https://github.com/fatedier/frp/releases/download/v0.33.0/frp_0.33.0_linux_amd64.tar.gz
tar zxvf frp_0.33.0_linux_amd64.tar.gz
cd frp_0.33.0_linux_amd64/
```

服务端的配置文件是 frps.ini，默认绑定 7000 端口，如果购置了云服务器，注意打开 7000 端口。

```shell
[common]
bind_port = 7000
```

通过 fprs 二进制文件启动 frp 服务。

```shell
./frps -c ./frps.ini
```

如下提示即是安装成功。

```shell
2020/05/15 22:16:29 [I] [service.go:178] frps tcp listen on 0.0.0.0:7000
2020/05/15 22:16:29 [I] [root.go:209] start frps success
2020/05/15 22:16:38 [I] [service.go:432] [e3c5096bd4291972] client login info: ip [14.114.230.168:44422] version [0.24.1] hostname [] os [linux] arch [amd64]
2020/05/15 22:16:38 [I] [tcp.go:63] [e3c5096bd4291972] [ssh] tcp proxy listen port [7001]
2020/05/15 22:16:38 [I] [control.go:445] [e3c5096bd4291972] new proxy [ssh] success
```

### 客户端安装配置

把自己的破电脑拿出来，以同样的方式下载 frp。

```shell
wget https://github.com/fatedier/frp/releases/download/v0.33.0/frp_0.33.0_linux_amd64.tar.gz
tar zxvf frp_0.33.0_linux_amd64.tar.gz
cd frp_0.33.0_linux_amd64/
```

客户端的配置文件是 frpc.ini。

```shell
[common]
server_addr = 127.0.0.1
server_port = 7000

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 6000
```

common 为通用配置

- server_addr 为公网服务器 IP 地址
- server_port 为公网服务器配置的 7000 端口

ssh 用于终端命令行访问

- type 连接类型，默认为 tcp
- local_ip 本地  IP
- local_port 用于 ssh 的端口号，默认 22
- remote_port 映射的服务端端口，访问该端口时默认转发到客户端的 22 端口

启动客户端进程

```shell
./frpc -c ./frpc.ini
```

如有以下提示则代表与服务端连接成功

```shell
2020/05/15 22:34:49 [I] [service.go:282] [9bc650122a538aab] login to server success, get run id [9bc650122a538aab], server udp port [0]
2020/05/15 22:34:49 [I] [proxy_manager.go:144] [9bc650122a538aab] proxy added: [ssh]
2020/05/15 22:34:49 [I] [control.go:179] [9bc650122a538aab] [ssh] start proxy success
```

### 测试

启动完成后就可以通过 ssh 连接到内网服务器了。

```shell
ssh -p 6000 enoch@xxx.xx.xxx.xxx
```