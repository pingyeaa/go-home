---
title: 如何进行 MySQL 性能调优
date: 2020-04-27 10:06:14
tags:
- mysql
- 性能
categories:
- [数据库, mysql]
---

## 背景

众所周知，Web API 响应慢可能包含很多方面的原因，比如第三方接口超时、DNS 解析慢、API 响应内容过大、网络带宽不够、硬件配置不足、网关层出现问题等，当然最常见且容易出问题的地方当属数据库层的使用，所以我们今天的主题只围绕数据库性能调优来展开。

## show status

当没有精确到具体 SQL 语句，而是觉得系统整体缓慢时，除了使用 vmstat 或 iostat 查看 CPU、进程、I/O 设备的使用情况外，还可以通过 show status 命令查询 mysql 整体执行频率。

```shell
mysql > show status;
```

进入 mysql 终端输入 show status 指令可以看到很多选项，比如语句的执行次数、连接数、锁表次数以及慢查询次数等等，但是我相信你想看的更多的是从上次 mysql 启动到现在的执行频率，所以只需要加上 global 就可以了，它会查询自服务启动后的统计结果，若不加，默认执行的是 show session status，意味着只查询本次连接内的统计结果，说实话我并没有想到它的应用场景，了解真相的同学可以留言给我。

```shell
mysql > show global status;
```

常见的变量有

- Com_select：执行 Select 操作的次数
- Com_update：执行 Update 操作的次数
- Com_insert：执行 Insert 操作的次数
- Com_delete: 执行 Delete 操作的次数
- Com_rollback：回滚次数
- Com_commit：提交次数
- Com_*：Com 开头的都是数据库相关操作的次数
- Innodb_row_lock_time：行锁定花费的总时间，单位毫秒
- Innodb_row_lock_time_avg：行锁定平均花费时间，单位毫秒
- Max_used_connections：服务器启动后使用的最大连接数量
- Uptime：服务器运行时间，单位秒
- Threads_connected：当前打开的连接数量
- Connections：试图连接 MySQL 服务器的数量，无论成功与否
- Aborted_connects：试图连接到服务器但失败的数量

从 show status 能看出什么问题呢，这个仁者见仁智者见智了，比如回滚次数 Com_rollback 非常多，那意味着代码一定存在问题，连接失败次数 Aborted_connects 过多可能是因为代码中没有及时或正确的关闭 mysql 连接等。

## 慢查询

show status 虽然可以查询系统整体的运行概况，但是无法精准定位到具体的 SQL 语句，哪个语句执行慢实际上是记录在 mysql 中的，当然它也有自己的开关，可以通过 show varirables 命令查看。

```shell
mysql > show variables like '%slow_query_log%';
```

```shell
+---------------------+--------------------------------------+
| Variable_name       | Value                                |
+---------------------+--------------------------------------+
| slow_query_log      | OFF                                  |
| slow_query_log_file | /var/lib/mysql/400d5ed8dd00-slow.log |
+---------------------+--------------------------------------+
2 rows in set (0.06 sec)
```

slow_query_log 意为开关，slow_query_log_file 是慢查询所在路径，开关可以通过 set 命令控制，但是只针对当前数据库生效，MySQL 重启会失效，如果要永久生效，必须修改 mysql 的配置文件。

```shell
mysql > set global slow_query_log=1;
```

```shell
# /etc/mysql/mysql.conf.d/mysqld.cnf

[mysqld]
......
slow_query_log=1
slow_query_log_file=/tmp/slow.log
long_query_time=1
```

定义“慢”的权利是掌握在用户手里的，可以通过 long_query_time 设置几秒以上才算慢，慢查询文件格式如下。

```shell
# Time: 2020-04-28T07:33:20.364348Z
# User@Host: root[root] @  [172.17.0.1]  Id:     2
# Query_time: 1.848906  Lock_time: 0.000206 Rows_sent: 0  Rows_examined: 2219780
use gorm;
SET timestamp=1588059200;
select * from vote_record where create_time like '%abc%';
```

mysql 会将所有执行超过 long_query_time 的语句记录下来，除此之外还包括时间戳、连接信息、执行时间等。

## show processlist

慢查询已经满足了绝大部分需求，但是只有在执行完毕的语句才会被记录，正在执行中的语句可以通过 show processlist 查看，我们执行 select sleep(5) 来做个测试。

```shell
mysql > select sleep(5);
mysql > show processlist;
```

```shell
+----+------+------------------+------+---------+------+------------+------------------------------------------------------------------------------------------------------+
| Id | User | Host             | db   | Command | Time | State      | Info                                                                                                 |
+----+------+------------------+------+---------+------+------------+------------------------------------------------------------------------------------------------------+
|  2 | root | 172.17.0.1:53890 | gorm | Sleep   |   84 |            | NULL                                                                                                 |
|  3 | root | 172.17.0.1:53892 | gorm | Query   |    2 | User sleep | select SLEEP(5)                                                                                      |
|  4 | root | 172.17.0.1:53894 | gorm | Sleep   |  106 |            | NULL                                                                                                 |
|  5 | root | 172.17.0.1:53896 | NULL | Sleep   |  106 |            | NULL                                                                                                 |
|  6 | root | localhost        | NULL | Query   |    0 | starting   | show processlist                                                                                     |
+----+------+------------------+------+---------+------+------------+------------------------------------------------------------------------------------------------------+
6 rows in set (0.00 sec)
```

show processlist 可以展示出正在运行的线程，除了 root 用户可以看到所有的线程外，其他用户只能看到自己执行的线程，字段解释如下。

- Id：线程的唯一标识
- User：启动该线程的用户
- Host：发出执行请求的客户端 IP 和端口号
- db：在哪个数据库中执行的
- Command：线程正在执行的命令，下文解释
- Time：在当前状态待了多久时间
- State：线程状态
- Info：线程执行的语句，默认显示前 100 个字符，查看全部字符执行 show full processlist

Command 字段包含如下命令（部分展示）

- Query：正在执行一个语句
- Quit：该线程正在推出
- Shutdown：正在关闭服务器
- Sleep：正在等待客户端发送请求语句
- Debug：线程正在生成调试信息
- Binlog Dump：正在将二进制日志同步到从节点
- ……

## 执行计划 explain

当定位到慢语句后，接下来需要分析语句，我们常用 explain 对语句分析，只需在语句前加上 explain 即可。

```shell
mysql > explain select * from vote_record where create_time like '%ssssss%';
```

explain 会大致评估语句的执行情况，有没有用到索引、查询了多少行等，字段如下。

- id：执行编号，在没有子查询的情况下默认为 1 
- select_type：查询类型，常见的有 SIMPLE、PRIMARY、UNION、SUBQUERY等
- table：表示正在访问哪个表
- type：表示访问类型，决定通过什么方式访问表，下文详解
- possible_keys：可能使用到的索引
- key：表示实际采用的哪个索引
- key_len：索引里使用的字节数
- ref：哪些列或常量被用于查找索引列上的值
- rows：估算出所要检索的行数
- extra：执行情况的说明描述，包含了不适合在其它列显示，但是又很重要的信息

### type

不同的访问类型对应性能不一，常见的访问类型有，性能由低到高排序

```shell
ALL、index、range、ref、eq_ref、const、system、NULL
```

- ALL：代表扫完全表所有数据才找到目标，性能肯定是最差的
- index：表示查完了所有的索引才找到目标，因为索引文件肯定比全表数据小，所以速度会快一些
- range：表示索引范围扫描，没有扫全部的索引，而是扫了一部分，自然比 index 性能好
- ref：表示使用了非唯一索引精确匹配到了某一行，这个比 range 更精准
- eq_ref：表示使用了唯一索引精准匹配到了某一行，唯一索引自然比非唯一要找得更快
- const/system：表示单表里最多一行匹配查询条件，比如对主键的查询
- NULL：表示不用访问表或索引就能取到数据

## show profiles

除了分析语句索引使用情况外，profile 可以清楚地让我们了解语句执行的过程。监测 profile 开关的语句是

```shell
mysql> select @@profiling;
+-------------+
| @@profiling |
+-------------+
|           0 |
+-------------+
```

可以通过 set 临时打开开关

```shell
mysql > set profiling=1;
```

打开收随便执行一条语句

```shell
mysql > select * from vote_record limit 100;
```

再通过 show profiles 就可以看到刚才执行的记录。

```shell
mysql> show profiles;
+----------+------------+-------------------------------------+
| Query_ID | Duration   | Query                               |
+----------+------------+-------------------------------------+
|        1 | 0.00086200 | select * from vote_record limit 100 |
+----------+------------+-------------------------------------+
1 row in set, 1 warning (0.00 sec)
```

一共三列，分别代表执行的标识、执行时间、执行语句，除此之外还可以指定查询某个 ID 的详情。

```shell
mysql> show profile for query 1;
+----------------------+----------+
| Status               | Duration |
+----------------------+----------+
| starting             | 0.000076 |
| checking permissions | 0.000021 |
| Opening tables       | 0.000067 |
| init                 | 0.000023 |
| System lock          | 0.000020 |
| optimizing           | 0.000014 |
| statistics           | 0.000026 |
| preparing            | 0.000021 |
| executing            | 0.000013 |
| Sending data         | 0.000340 |
| end                  | 0.000049 |
| query end            | 0.000038 |
| closing tables       | 0.000023 |
| freeing items        | 0.000060 |
| cleaning up          | 0.000072 |
+----------------------+----------+
15 rows in set, 1 warning (0.00 sec)
```

可以清晰地看出每个阶段执行耗时，实际并不止可以看阶段耗时，还能展示 CPU、IO、内存等信息，感兴趣可以自行尝试。

```shell
mysql> show profile cpu, block io, memory for query 1;
+----------------------+----------+----------+------------+--------------+---------------+
| Status               | Duration | CPU_user | CPU_system | Block_ops_in | Block_ops_out |
+----------------------+----------+----------+------------+--------------+---------------+
| starting             | 0.000076 | 0.000000 |   0.000000 |            0 |             0 |
| checking permissions | 0.000021 | 0.000000 |   0.000000 |            0 |             0 |
| Opening tables       | 0.000067 | 0.000000 |   0.000000 |            0 |             0 |
| init                 | 0.000023 | 0.000000 |   0.000000 |            0 |             0 |
| System lock          | 0.000020 | 0.000000 |   0.000000 |            0 |             0 |
| optimizing           | 0.000014 | 0.000000 |   0.000000 |            0 |             0 |
| statistics           | 0.000026 | 0.000000 |   0.000000 |            0 |             0 |
| preparing            | 0.000021 | 0.000000 |   0.000000 |            0 |             0 |
| executing            | 0.000013 | 0.000000 |   0.000000 |            0 |             0 |
| Sending data         | 0.000340 | 0.000000 |   0.000000 |            0 |             0 |
| end                  | 0.000049 | 0.000000 |   0.000000 |            0 |             0 |
| query end            | 0.000038 | 0.000000 |   0.000000 |            0 |             0 |
| closing tables       | 0.000023 | 0.000000 |   0.000000 |            0 |             0 |
| freeing items        | 0.000060 | 0.000000 |   0.000000 |            0 |             0 |
| cleaning up          | 0.000072 | 0.000000 |   0.000000 |            0 |             0 |
+----------------------+----------+----------+------------+--------------+---------------+
15 rows in set, 1 warning (0.01 sec)
```





