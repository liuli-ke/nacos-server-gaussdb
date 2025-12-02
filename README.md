# Nacos 2.2.0 for GaussDB

> 可能未充分测试，后续遇到问题再处理

## 说明

> 这里使用的是同事基于华为gaussdb jdbc 505.2.1的jdbc包构建的nacos插件
>
> 此项目对应的 `nacos-server.jar` 在 `nacos-server.7z` 里(由于gitee的大小限制个人只能压缩上传了)
>
> `bin/docker-startup.sh`：完全就是官方构建docker镜像的Dockerfile内容
>
> `conf/application.properties`：是修改了官方构建镜像的内容，修改内容:
>
> ```properties
> spring.datasource.platform=${SPRING_DATASOURCE_PLATFORM:gaussdb}
> db.num=${GAUSSDB_DATABASE_NUM:1}
> db.url.0=jdbc:gaussdb://${GAUSSDB_SERVICE_HOST}:${GAUSSDB_SERVICE_PORT:8000}/${GAUSSDB_SERVICE_DB_NAME}?currentSchema=${GAUSSDB_SERVICE_SCHEMA:nacos}&${GAUSSDB_SERVICE_DB_PARAM:tcpKeepAlive=true&reWriteBatchedInserts=true&ApplicationName=nacos-gaussdb}
> db.user.0=${GAUSSDB_SERVICE_USER}
> db.password.0=${GAUSSDB_SERVICE_PASSWORD}
> db.pool.config.driverClassName=com.huawei.gaussdb.jdbc.Driver
> ```
>
> `conf/nacos-gaussdb.sql`：目前测试在分布式GaussDB环境下，兼容模式为(MySQL、PG)建库均可使用，注意：兼容ORACLE建库不可使用，主要原因是`config_info`表的`tenant_id`字段在默认命名空间创建配置会有问题，具体表现为：正常情况在默认命名空间创建配置时`tenant_id`字段会为空字符串，但是在兼容ORACLE模式建库的情况下新建配置`tenant_id`字段值会变成`NULL`值
>
> `nacos-server.jar`：在`nacos-server.7z`压缩包里拿，实际就是将`gaussdb-plugin/nacos-gaussdb-datasource-plugin-ext-1.0.0.jar`放到了jar包里`BOOT-INF\lib`下。

## 镜像构建

```bash
$ docker build -t 'liulik/nacos-server:v2.2.0-gaussdb-slim' .
# 可以直接从Docker Hub上拉取(这两个是同一个镜像)：
# liulik/nacos-server:v2.2.0.1-gaussdb-slim
# liulik/nacos-server:v2.2.0-gaussdb-slim
```

## 使用

### 负载均衡IP连接

```bash
$ docker run -d \
  --name nacos-gaussdb \
  -p 7848:7848 \
  -p 8848:8848 \
  -p 9848:9848 \
  -p 9849:9849 \
  -e SPRING_DATASOURCE_PLATFORM='gaussdb' \
  -e GAUSSDB_DATABASE_NUM='1' \
  -e GAUSSDB_SERVICE_HOST='xxx.xxx.xxx.xxx' \
  -e GAUSSDB_SERVICE_PORT='8000' \
  -e GAUSSDB_SERVICE_DB_NAME='nacos' \
  -e GAUSSDB_SERVICE_SCHEMA='nacos' \
  -e GAUSSDB_SERVICE_DB_PARAM='tcpKeepAlive=true&reWriteBatchedInserts=true&ApplicationName=nacos-gaussdb' \
  -e GAUSSDB_SERVICE_USER='nacos' \
  -e GAUSSDB_SERVICE_PASSWORD='nacos' \
  liulik/nacos-server:v2.2.0-gaussdb-slim
```

### 集群IP连接

> 其实就是把另外的IP端口都写在`GAUSSDB_SERVICE_HOST`里，最后一个端口分开，修改 `application.properties` 时没有考虑到这块问题，镜像都打了懒得改了

```bash
$ docker run -d \
  --name nacos-gaussdb \
  -p 7848:7848 \
  -p 8848:8848 \
  -p 9848:9848 \
  -p 9849:9849 \
  -e SPRING_DATASOURCE_PLATFORM='gaussdb' \
  -e GAUSSDB_DATABASE_NUM='1' \
  -e GAUSSDB_SERVICE_HOST='xxx.xxx.xxx.aaa:8000,xxx.xxx.xxx.bbb:8000,xxx.xxx.xxx.ccc' \
  -e GAUSSDB_SERVICE_PORT='8000' \
  -e GAUSSDB_SERVICE_DB_NAME='nacos' \
  -e GAUSSDB_SERVICE_SCHEMA='nacos' \
  -e GAUSSDB_SERVICE_DB_PARAM='tcpKeepAlive=true&reWriteBatchedInserts=true&ApplicationName=nacos-gaussdb' \
  -e GAUSSDB_SERVICE_USER='nacos' \
  -e GAUSSDB_SERVICE_PASSWORD='nacos' \
  liulik/nacos-server:v2.2.0-gaussdb-slim
```

> 插件在[wuchubuzai2018/nacos-datasource-extend-plugins](https://github.com/wuchubuzai2018/nacos-datasource-extend-plugins)项目基础上改的



## 其他说明

镜像TAG带auth的，是配置了`nacos.core.auth.enabled`的，如果自行使用，参考：

```bash
$ docker run -d \
  --name nacos-gaussdb \
  -p 7848:7848 \
  -p 8848:8848 \
  -p 9848:9848 \
  -p 9849:9849 \
  -e SPRING_DATASOURCE_PLATFORM='gaussdb' \
  -e GAUSSDB_DATABASE_NUM='1' \
  -e GAUSSDB_SERVICE_HOST='xxx.xxx.xxx.aaa:8000,xxx.xxx.xxx.bbb:8000,xxx.xxx.xxx.ccc' \
  -e GAUSSDB_SERVICE_PORT='8000' \
  -e GAUSSDB_SERVICE_DB_NAME='nacos' \
  -e GAUSSDB_SERVICE_SCHEMA='nacos' \
  -e GAUSSDB_SERVICE_DB_PARAM='tcpKeepAlive=true&reWriteBatchedInserts=true&ApplicationName=nacos-gaussdb' \
  -e GAUSSDB_SERVICE_USER='nacos' \
  -e GAUSSDB_SERVICE_PASSWORD='nacos' \
  -e NACOS_AUTH_SYSTEM_ENABLE=true \
  -e NACOS_AUTH_TOKEN='SecretKeyxxx' \
  -e NACOS_AUTH_IDENTITY_KEY='nacos' \
  -e NACOS_AUTH_IDENTITY_VALUE='nacos' \
  liulik/nacos-server:v2.2.0-gaussdb-auth-slim
```

> 也可以自行将application.properties配置挂出来修改