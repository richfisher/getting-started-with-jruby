## Preface
I'm trying to do [some integrations](https://github.com/richfisher/jruby_activiti) with jruby and java. I encountered some problems, and found that there were only a few information about jruby. So I write down my experience and share it.

## Install JRuby
Environment: Mac, rvm

	rvm get head
	rvm install jruby-9.0.4.0
	
in your project folder, run
	
	rvm use jruby-9.0.4.0
	
or create a `.ruby-version` file

	echo 'jruby-9.0.4.0' > .ruby-version
	

## Calling Java
create a folder named `getting-started-with-jruby`, you can find the code in [Github](https://github.com/richfisher/getting-started-with-jruby)

### quick start
create a `Hello.java` 

	public class Hello {
		public static void world(){
			System.out.println("Hello JRuby!");
		}
	}

compile it with `javac Hello.java`

`require 'java'` will give you access to any bundled Java libraries (classes within your java class path) 

then we create a `calling-class-in-root.rb`

	require 'java'
	Java::Hello.world()

run `ruby calling-class-in-root.rb` in termial, and you will see the output. `Hello JRuby!`

### classpath
Everything in the Ruby load path is considered to be a classpath entry, so .class files under load path hierarchies are automatically available to be referenced from code.

The classpath is typically set up through the CLASSPATH environment variable or passed to the java command using -cp or -classpath with a delimited list of filesystem locations.

We can add classpath

	$CLASSPATH << "classes"
	# or $CLASSPATH << "file:///#{File.expand_path('classes')}/"


we create a java file `java/src/main/java/SubHello.java`, and compile the java file.

create `calling-class-in-sub-folder.rb` in project root.

	require 'java'
	$CLASSPATH << "java/src/main/java"

	Java::SubHello.world()

run `ruby calling-class-in-sub-folder.rb` in termial, and you will see the output. `Hello jruby in sub folder!`


### import jar file
require 'path/to/mycode.jar'

create a `pom.xml` in `java` folder, run `mvn package` and we get `demo-1.0.jar`

create `calling-jar.rb` in project root, 

	require 'java'
	require './java/target/demo-1.0.jar'
	Java::SubHello.world()

run `ruby calling-jar.rb` in termial, and you will see the output. `Hello jruby in sub folder!`


### jbundler
install JBundler with

	gem install jbundler

create a Jarfile, something like:

	jar 'commons-io:commons-io', '2.4'
	
run `jbundle install` in terminal

`require 'jbundler'` will give you access to Java libraries announced in Jarfile

create `calling-jar-with-jbundler.rb`

	require 'java'
	require 'jbundler'

	file = java.io.File.new('./Jarfile')
	lines = org.apache.commons.io.FileUtils.readLines(file, "UTF-8")
	puts lines

we will see the output `[jar 'commons-io:commons-io', '2.4']`

we can also calling java in caml style, and get the same result

	require 'java'
	require 'jbundler'
	
	file = Java::JavaIo::File.new('./Jarfile')
	lines = Java::OrgApacheCommonsIo::FileUtils.readLines(file, "UTF-8")
	puts lines

## Speedup initialization
JRuby initialization is much more slower than MRI Ruby, and we will speedup it.

### --dev flag
Use the "--dev" flag, this enables the following settings:

* client mode where applicable (generally older 32-bit JVMs). The client mode is designed to start up quickly and not optimize as much. 
* TieredCompilation and TieredStopAtLevel=1, equivalent to client mode on newer Hotspot-based JVMs
* compile.mode=OFF to disable JRuby's JVM bytecode compiler
* jruby.compile.invokedynamic=false to disable the slow-to-warmup invokedynamic features of JRuby

If you don't need code to be fast but you want the application to start up quickly, this option may be good for you.

### use --dev flag with rvm

RVM supports PROJECT_JRUBY_OPTS with two provided hook files (currently, after_use_jruby and after_use_jruby_opts). If enabled by making them executable, the hooks use the script library functions jruby_options_append and jruby_options_remove to append/remove the options in PROJECT_JRUBY_OPTS to/from JRUBY_OPTS.

	chmod +x $rvm_path/hooks/after_use_jruby_opts
	echo 'PROJECT_JRUBY_OPTS=(--dev)' > ~/.rvmrc

### tools
rails/spring MRI Ruby only, they use `fork` which doesn't work on JRuby

spork, not work. start with error `TypeError: no implicit conversion of Fixnum into String`

[theine](https://github.com/mrbrdo/theine) Rails pre-loader designed to work on JRuby
gem install thenine
`theine_server`
`time thenine rake test` 4.882s
`time theine runner "puts Rails.env"` 4.464s

[drip](https://github.com/ninjudd/drip) Fast JVM launching
not working with rails runner

### benchmark
create two project.

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


Using `--dev` flag, we can roughly cut 45% time when initialization. And `theine` is a good option.

##  Performance
While the start up time of JRuby is quite slow, how about the performance?

Using `ab` to test the two blank rails projects.

|                  | Ruby on Rails | JRuby on Rails |
|------------------|---------------|----------------|
| ab -n 1000 -c 1  | 22.103ms      | 16.275ms       |
| ab -n 1000 -c 10 | 22.079ms      | 12.622ms       |
| ab -n 1000 -c 50 | 22.051ms      | 12.236ms       |

Well, looks good!

## Reference 
1. https://github.com/jruby/jruby/wiki/ClasspathAndLoadPath
2. https://github.com/jruby/jruby/wiki/Improving-startup-time
2. http://stackoverflow.com/questions/8283300/how-do-i-use-jruby-opts-with-rvm
3. http://blog.headius.com/2009/05/jruby-nailgun-support-in-130.html
4. https://github.com/mrbrdo/theine
5. http://stackoverflow.com/questions/2224178/how-to-improve-jruby-load-time
6. https://github.com/ninjudd/drip
7. https://gist.github.com/rwjblue/4582914