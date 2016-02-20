## 前言
最近尝试在JRuby里集成[Java组件](https://github.com/richfisher/jruby_activiti)，遇到不少小问题，关于JRuby的资料不多，记录下一些心得。

## 安装 JRuby
环境和工具：Mac, rvm

```
rvm get head
rvm install jruby-9.0.4.0	
rvm use jruby-9.0.4.0
```

你也可以创建一个`.ruby-version`文件在项目目录，进入目录就会自动切换至JRuby。

```
echo 'jruby-9.0.4.0' > .ruby-version
```

## 调用 Java
首先创建一个目录 `getting-started-with-jruby`, 下面的代码都可以在[Github](https://github.com/richfisher/getting-started-with-jruby)找到。

### quick start
创建一个Java文件 `Hello.java` 

```
public class Hello {
	public static void world(){
		System.out.println("Hello JRuby!");
	}
}
```

编译成class文件 `javac Hello.java`

在JRuby里`require 'java'` 后你可以访问所有在classpath里的java classes。

创建一个ruby文件 `calling-class-in-root.rb`

```
require 'java'
Java::Hello.world()
```

在命令行运行 `ruby calling-class-in-root.rb`, 看到输出 `Hello JRuby!`

### classpath
运行jruby所在的目录是classpath, 所有运行目录里的`.class`文件可以在JRuby里访问。

classpath可以通过设置CLASSPATH环境变量进行扩展

```
$CLASSPATH << "classes"
# or $CLASSPATH << "file:///#{File.expand_path('classes')}/"
```

创建一个java文件 `java/src/main/java/SubHello.java`, 并编译。

在项目目录创建一个ruby文件 `calling-class-in-sub-folder.rb`.

```
require 'java'
$CLASSPATH << "java/src/main/java"

Java::SubHello.world()
```

在命令行运行 `ruby calling-class-in-sub-folder.rb`, 看到输出 `Hello jruby in sub folder!`


### import jar file
jar文件须在classpath或者手动require

	require 'path/to/mycode.jar'

在`java`目录创建`pom.xml`,  运行 `mvn package` 打包成 `demo-1.0.jar`

在项目目录创建一个ruby文件 `calling-jar.rb`, 

```
require 'java'
require './java/target/demo-1.0.jar'
Java::SubHello.world()
```

在命令行运行 `ruby calling-jar.rb`, 看到输出 `Hello jruby in sub folder!`


### jbundler
像`bundler`一样管理jar依赖，首先安装

	gem install jbundler

在项目目录创建`Jarfile`:

	jar 'commons-io:commons-io', '2.4'
	
在命令行运行 `jbundle install` 安装声明的jar包。

在JRuby里`require 'jbundler'`后，你将能调用Jarfile里声明的包

在项目目录创建一个ruby文件 `calling-jar-with-jbundler.rb`

```
require 'java'
require 'jbundler'

file = java.io.File.new('./Jarfile')
lines = org.apache.commons.io.FileUtils.readLines(file, "UTF-8")
puts lines
```

你将看到输出 `[jar 'commons-io:commons-io', '2.4']`

你也可以使用驼峰风格调用java

```
require 'java'
require 'jbundler'

file = Java::JavaIo::File.new('./Jarfile')
lines = Java::OrgApacheCommonsIo::FileUtils.readLines(file, "UTF-8")
puts lines
```

## 加速JRuby启动

### JRuby 的 --dev 参数
使用 "--dev" 参数等价于同时设置以下几个JRuby参数:

* client mode where applicable (generally older 32-bit JVMs). The client mode is designed to start up quickly and not optimize as much. 
* TieredCompilation and TieredStopAtLevel=1, equivalent to client mode on newer Hotspot-based JVMs
* compile.mode=OFF to disable JRuby's JVM bytecode compiler
* jruby.compile.invokedynamic=false to disable the slow-to-warmup invokedynamic features of JRuby

在开发过程，想要程序启动更快而不关心运行效率，--dev参数应该不错。

### 在rvm使用 --dev 参数

RVM提供了一个hook文件`$rvm_path/hooks/after_use_jruby_opts`，将它变成可执行之后，每次切换至JRuby会根据环境变量PROJECT_JRUBY_OPTS添加JRuby的启动参数。

```
chmod +x $rvm_path/hooks/after_use_jruby_opts
echo 'PROJECT_JRUBY_OPTS=(--dev)' > ~/.rvmrc
```

### 其他工具
* [X] rails/spring 只支持MRI Ruby, JRuby不支持`fork`

* [X] spork, 启动报错 `TypeError: no implicit conversion of Fixnum into String`

* [✓] [theine](https://github.com/mrbrdo/theine) 与Spork类似
`theine_server`
`thenine some command`

* [X] [drip](https://github.com/ninjudd/drip)
运行`rails runner`挂死

### 速度测试
分别用MRI Ruby和JRuby创建两个Rails项目。

```
rvm use 2.2.3
gem install rails
rails new ruby-on-rails

rvm use jruby-9.0.4.0
gem install rails
rails new jruby-on-rails

time rake test
time rails s
time rails runner "puts Rails.env"
```

|            | ruby   | jruby   | jruby --dev | theine|
|------------|--------|---------|-------------|-------|
| rake test  | 3.841s | 13.547s | 7.451s      |4.882s |
| rails s    | 4.796s | 20.914s | 11.833s     |5.084s |
|rails runner| 2.128s | 17.116s | 9.718s      |4.464s |


总结：使用 `--dev` 参数可以减少大约45%的启动时间， 使用 `theine` 还能进一步加速.

##  关于JRuby的运行效率
JRuby的启动速度比较糟糕，运行效率又怎么样呢？

还是对两个空白的Rails项目进行简单的测试

|                  | Ruby on Rails | JRuby on Rails |
|------------------|---------------|----------------|
| ab -n 1000 -c 1  | 22.103ms      | 16.275ms       |
| ab -n 1000 -c 10 | 22.079ms      | 12.622ms       |
| ab -n 1000 -c 50 | 22.051ms      | 12.236ms       |

虽然不代表真实的项目，从结果来看JRuby的运行效率是不错的。

## 参考资料 
* https://github.com/jruby/jruby/wiki/ClasspathAndLoadPath
* https://github.com/mkristian/jbundler
* https://github.com/jruby/jruby/wiki/Improving-startup-time
* http://stackoverflow.com/questions/8283300/how-do-i-use-jruby-opts-with-rvm
* http://blog.headius.com/2009/05/jruby-nailgun-support-in-130.html
* https://github.com/mrbrdo/theine
* http://stackoverflow.com/questions/2224178/how-to-improve-jruby-load-time
* https://github.com/ninjudd/drip
* https://gist.github.com/rwjblue/4582914