---
title: 如何用Github钩子做自动部署
date: 2020-04-22 10:27:34
tags: 
- github
- webhooks
- 钩子
categories: 
- 杂谈
---

最近机缘巧合的购置了域名和服务器，不用实在是浪费，再加上一直没有属于自己的个人网站，所以打算用hexo在服务器上玩一下，这样也就不用再纠结用Github pages还是Gitee pages了。当然，今天的主题并不是博客搭建，而是如何利用Github的钩子，将博客代码部署到服务器上。

毕竟Github的钩子已经历史悠久了，网上有很多开源项目可以拿来用，所以我并没有造轮子，而是去找了5K star的开源Go项目`webhook`，这个工具的作用是接收Github仓库的变动通知，然后调用你配置好的shell脚本，脚本可以写上代码拉取的命令或是编译的操作等，具体根据个人需求而定。简而言之，它只起着拉通Github与你服务器的作用。

![file](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1587526481705.png)

### webhook工具安装

因为webhook是Go语言开发的，所以要先安装Go语言。

```shell
yum install -y golang
```

然后就可以用go命令安装webhook了。

```shell
go get github.com/adnanh/webhook
```

命令安装位置可以通过`go env`查看，GOPATH就是命令安装路径，比如我的命令就安装在/root/go/bin/webhook。

```shell
go env
...
GOOS="linux"
GOPATH="/root/go"
...
```

### 生成ssh key

在编写脚本之前确保服务器有权限拉取github代码，如果已经做了配置可跳过本节去看[部署脚本编写](#部署脚本编写)。ssh key是代码托管平台（github、gitee、coding、gitlab等）鉴别你是否有权拉取代码的身份标识，生成只需一行命令和一路回车就行了。

```shell
ssh-keygen

Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa): 
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:M6sCf/J/hOu3zLxMkFUVmv3iWIa30CfbxiWqmWCt1YE root@iZwz96y36tk2ecnykzituxZ
The key's randomart image is:
+---[RSA 2048]----+
|            ..o. |
|           . o   |
|          . o    |
|       . o .     |
|      E S.  .    |
|  .  . ..Oo ..   |
|   oo o ==Boo .  |
|   .++.+o#== .   |
|    .=*+=+@o     |
+----[SHA256]-----+
```

生成后可通过`cat ~/.ssh/id_rsa.pub`命令查看，最后将key加入github即可，加法不再赘述，请自行谷歌。

```shell
cat ~/.ssh/id_rsa.pub

ssh-rsa AAAAB3NzaC1yc2EAAAADAQHBAAABAQCv7LGVJUFdcLL+HZyRFTQIQCdre61Gch76lDVpmWSX9BGGRU3iQS7EU5qApFn1VSvt+yf4rMt2LEkuxGCm1wIyBKZ6LYDViZBeTAfx4BcM1mcpxOX6I/+r07mQ4llTz+poQB1Zp9Y60uk0tbGOVWlCoDBEvf9qeEnQ0qEczEkv7wcawV6pVhlXjFKZgq0EOQbCYoWMvPUl+dwDbTcl/h+7At1nlgfF7IuRHlKf18qvgnTRT2wpiuz4pWdoAi8LcY1JiR1z5OB0oCJ2euhyDND39G2NxZRS1FIVdgCEvioHtdoHOSoWBlcSj0fLFSnscBfRBrCd7yhOP7fFKfrowHMj root@iZwz96y36tk2ecnykzituxZ
```

### 部署脚本编写

该shell脚本的主要目的是从github拉取代码，脚本内容很简单，只做了目录的简要判断，代码目录存在则更新，不存在则克隆仓库，工作目录和仓库名称、地址请换成自己的。

```shell
#!/bin/bash

cd /home/www/website

if [ ! -d "go-home" ]; then
  git clone https://github.com/pingyeaa/go-home.git
fi

cd go-home
git pull
```

### webhook配置与启动

编写配置文件hooks.json，格式如下。

```json
[
  {
    "id": "deploy-webhook",
    "execute-command": "deploy.sh",
    "command-working-directory": "/home"
  }
]
```

- id：钩子的id，可自定义
- execute-command：要执行的脚本名，就是刚才编写的部署脚本
- command-working-directory：脚本所在目录

完成后通过webhook命令启动，可以看到id为deploy-webhook的配置已经加载了，我们需要注意的是监听的端口和路径，等下要用到。

```shell
/root/go/bin/webhook -hooks hooks.json -verbose

[webhook] 2020/04/22 15:18:22 version 2.6.11 starting
[webhook] 2020/04/22 15:18:22 setting up os signal watcher
[webhook] 2020/04/22 15:18:22 attempting to load hooks from hooks.json
[webhook] 2020/04/22 15:18:22 found 1 hook(s) in file
[webhook] 2020/04/22 15:18:22   loaded: deploy-webhook
[webhook] 2020/04/22 15:18:22 serving hooks on http://0.0.0.0:9000/hooks/{id}
[webhook] 2020/04/22 15:18:22 os signal watcher ready
```

```shell
http://0.0.0.0:9000/hooks/{id}
```

### Github Webhooks配置

现在服务器已经启动了webhook程序监听9000端口，接下来仅需要告诉Github这个地址和端口就好了。

打开仓库设置页，添加webhook。

![](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1587523289550.png)

配置webhooks，Payload URL就是要通知的地址，把刚才打印出的端口和路径填上即可，其他默认。

![file](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1587541102651.png)

现在可以提交代码测试了，如果推送失败Github中会有错误提示，同样的，成功不仅在Github中能看到，服务器的打印日志也有记录。

![file](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1587541394355.png)

![file](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1587541482026.png)