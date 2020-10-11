---
title: Golang如何操作excel
date: 2020-10-11 23:24:19
tags:
- excel
categories:
- [golang, excel]
---

### 关键术语介绍

为了方便开源库的快速上手，我们先来了解 excel 中的几个关键术语，如下图所示，①为sheet，也就是表格中的页签；②为row，代表 excel 中的一行；③为cell，代表 excel 中的一个单元格。

![](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1602348679727.png)

正常情况下，创建一个表格的基本流程是打开 wps 点击新建，这时会默认创建一个 sheet，然后在该 sheet 中的第一行填写表头，接下来根据表头逐行填充内容，最后将文件另存为到硬盘的某个位置。这与 Golang 开源库创建 excel 的流程基本相同，下面演示一个极简表格的创建。

### 创建表格

创建表格前需要先引入 excel 库，我们以比较热门的 **tealeg/xlsx** 库为例。

```shell
go get github.com/tealeg/xlsx
```

首先创建一个空文件，拿到文件句柄。

```go
file := xlsx.NewFile()
```

创建一个名为`人员信息收集`的 sheet。

```go
sheet, err := file.AddSheet("人员信息收集")
if err != nil {
  panic(err.Error())
}
```

然后为该 sheet 创建一行，这行作为我们的表头。

```go
row := sheet.AddRow()
```

在该行中创建一个单元格。

```go
cell := row.AddCell()
```

现在给单元格填充内容，因为是表头，暂且叫`姓名`。

```go
cell.Value = "姓名"
```

如何创建第二个单元格呢？原理相同，此处 cell 变量已定义，再创建新单元格只需赋值即可。

```go
cell = row.AddCell()
cell.Value = "性别"
```

表头已经设置好了，可以开始创建第二行来填充内容了，方式与上述无差别。

```go
row = sheet.AddRow()
cell = row.AddCell()
cell.Value = "张三"
cell = row.AddCell()
cell.Value = "男"
```

表格设置完成后，将该文件保存，文件名可自定义。

```go
err = file.Save("demo.xlsx")
if err != nil {
  panic(err.Error())
}
```

跑起来后，可以发现目录中多了一个 demo.xlsx 文件，打开预览内容如下，达到了预期效果。

![](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1602403048980.png)

**文件源码**

```go
package main

import "github.com/tealeg/xlsx"

func main() {
	file := xlsx.NewFile()
	sheet, err := file.AddSheet("人员信息收集")
	if err != nil {
		panic(err.Error())
	}
	row := sheet.AddRow()
	cell := row.AddCell()
	cell.Value = "姓名"
	cell = row.AddCell()
	cell.Value = "性别"

	row = sheet.AddRow()
	cell = row.AddCell()
	cell.Value = "张三"
	cell = row.AddCell()
	cell.Value = "男"

	err = file.Save("demo.xlsx")
	if err != nil {
		panic(err.Error())
	}
}
```

### 读取表格

表格的读取比创建简单很多，依然以上文创建的文件为例。

```go
output, err := xlsx.FileToSlice("demo.xlsx")
if err != nil {
  panic(err.Error())
}
```

只需将文件路径传入上述方法，即可自动读取并返回一个三维切片，我们来读取第一个 sheet 的第二行中的第一个单元格。

```go
log.Println(output[0][1][1]) //Output: 男
```

由此一来就非常容易遍历了。

```go
for rowIndex, row := range output[0] {
  for cellIndex, cell := range row {
    log.Println(fmt.Sprintf("第%d行，第%d个单元格：%s", rowIndex+1, cellIndex+1, cell))
  }
}
```

```go
2020/10/11 16:15:29 第1行，第1个单元格：姓名
2020/10/11 16:15:29 第1行，第2个单元格：性别
2020/10/11 16:15:29 第2行，第1个单元格：张三
2020/10/11 16:15:29 第2行，第2个单元格：男
```

**文件源码**

```go
package main

import (
	"fmt"
	"github.com/tealeg/xlsx"
	"log"
)

func main() {
	output, err := xlsx.FileToSlice("demo.xlsx")
	if err != nil {
		panic(err.Error())
	}
	log.Println(output[0][1][1])
	for rowIndex, row := range output[0] {
		for cellIndex, cell := range row {
			log.Println(fmt.Sprintf("第%d行，第%d个单元格：%s", rowIndex+1, cellIndex+1, cell))
		}
	}
}
```

### 修改表格

只是读取表格内容可能在特定场景下无法满足需求，有时候需要对表格内容进行更改。

```go
file, err := xlsx.OpenFile("demo.xlsx")
if err != nil {
  panic(err.Error())
}
```

修改表格之前依然需要先读取文件，只是这次并没有直接将其转化为三维切片。拿到文件句柄后，可以直接修改某一行的内容。

```go
file.Sheets[0].Rows[1].Cells[0].Value = "李四"
```

上述代码将第二行的张三改为了李四，但这还没有结束，接下来需要将文件重新保存。

```go
err = file.Save("demo.xlsx")
if err != nil {
  panic(err.Error())
}
```

打开文件预览，可以看到已经成功将张三改为了李四。

![](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1602405538334.png)

**文件源码**

```go
package main

import "github.com/tealeg/xlsx"

func main() {
	file, err := xlsx.OpenFile("demo.xlsx")
	if err != nil {
		panic(err.Error())
	}
	file.Sheets[0].Rows[1].Cells[0].Value = "李四"
	err = file.Save("demo.xlsx")
	if err != nil {
		panic(err.Error())
	}
}
```

### 样式设置

该开源库不仅支持内容的编辑，还支持表格的样式设置，样式统一由结构体 Style 来负责。

```go
type Style struct {
	Border          Border
	Fill            Fill
	Font            Font
	ApplyBorder     bool
	ApplyFill       bool
	ApplyFont       bool
	ApplyAlignment  bool
	Alignment       Alignment
	NamedStyleIndex *int
}
```

拿上述生成的文件为例，假如我要将姓名所在单元格居中，首先要实例化样式对象。

```go
style := xlsx.NewStyle()
```

赋值居中属性。

```go
style.Alignment = xlsx.Alignment{
  Horizontal:   "center",
  Vertical:     "center",
}
```

给第一行第一个单元格设置样式。

```go
file.Sheets[0].Rows[0].Cells[0].SetStyle(style)
```

与修改表格处理逻辑相同，最后保存文件。

```go
err = file.Save("demo.xlsx")
if err != nil {
  panic(err.Error())
}
```

打开预览，可以看到文字已经上下左右居中。

![](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1602413052099.png)

同理，可以修改文字颜色和背景，同样通过 style 的属性来设置。

```go
style.Font.Color = xlsx.RGB_Dark_Red
style.Fill.BgColor = xlsx.RGB_Dark_Green
```

![](http://pingyeaa.oss-cn-shenzhen.aliyuncs.com/image-1602413398061.png)

其他还有很多属性可以设置，比如合并单元格、字体、大小等等，大家可以自行测试。

**文件源码**

```go
package main

import "github.com/tealeg/xlsx"

func main() {
	file, err := xlsx.OpenFile("demo.xlsx")
	if err != nil {
		panic(err.Error())
	}
	style := xlsx.NewStyle()
	style.Font.Color = xlsx.RGB_Dark_Red
	style.Fill.BgColor = xlsx.RGB_Dark_Green
	style.Alignment = xlsx.Alignment{
		Horizontal:   "center",
		Vertical:     "center",
	}
	file.Sheets[0].Rows[0].Cells[0].SetStyle(style)
	err = file.Save("demo.xlsx")
	if err != nil {
		panic(err.Error())
	}
}
```

