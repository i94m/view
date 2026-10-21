# PhpStorm

## 关联PHP解释器

1.打开设置，选中 `PHP` 配置项，添加新的 `CLI 解释器`

![](/image/view/ide/1.png)

点击 `+` 号添加

![](/image/view/ide/2.png)

2.选中 `From Docker ...` 选项

![](/image/view/ide/3.png)

3.类型选择 `Docker` ，镜像名称选择 `rtwadewang/view`

![](/image/view/ide/4.png)

4.如果PHP信息正确，点击 `确定` 按钮配置成功

![](/image/view/ide/5.png)

## 配置Xdebug

> 配置`Xdebug`前，请先按照上面的步骤关联好PHP解释器

1.打开设置，选中 `PHP` 配置项，添加新的 `服务器`
![](/image/view/ide/6.png)

2.填写配置信息，注意映射的项目路径
![](/image/view/ide/7.png)

3.点击工具栏的`调试模式`，添加新的配置
![](/image/view/ide/8.png)

![](/image/view/ide/9.png)

4.选择`PHP远程调试`
![](/image/view/ide/10.png)

5.填写配置信息，注意会话ID
![](/image/view/ide/11.png)

6.点击工具栏的`调试模式`，选择刚刚新加的配置名称
![](/image/view/ide/12.png)

7.打开调试日志，开始测试
![](/image/view/ide/13.png)
