### Issue with APIs (haven't tested with deals yet)

#### Common
1. 客户和客户渠道的API返回数据格式和出错信息不一致。比如：
    * 搜索客户返回一个hash，搜索客户渠道返回一个array
    * 删除客户返回204，删除客户渠道返回500
    * 如果创建新客户的mobile如果和已经存在客户一样，API返回旧客户信息，不会再建一个新客户。客户渠道每次创建都是新纪录。
2. GET /v1/xxx/id 和 DELETE /v1/xxx/id 如果id不存储会返回500。按惯例应该返回404
3. 无效的access token返回200，错误信息在payload里面。按惯例应该返回401。
4. 不支持标准的oauth2 http header 'Authorization: Bearer xxx'
5. 只支持一个acess token，多进程的客户要增加负担来实现共享一个access token。
6. DELETE 比其它动作明显要慢。
7. 是不是所有appid都能看到，更新和删除所有的数据？

#### 客户API
1. 按mobile搜索返回结果是正确的，按其它任何字段搜索都被忽略，返回所有的记录。

#### 客户渠道
1. 好像没有unique constraint。可以创建多个所有字段都一样的记录
2. customer id输入没有校验，不存在的数值也一样成功

#### 客户事件
1. customer id输入没有校验，不存在的数值也一样成功
2. 有unique constraint，但是文档没有说明在那些字段上
