---

title: 如何用Github钩子做自动部署
date: 2020-04-22 10:27:34
tags: github,webhooks,钩子
categories: 杂谈
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

webhook工具是用来

![](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1587523289550.png)