[magic]: https://www.chiark.greenend.org.uk/~sgtatham/aliases.html
[PuTTY]: https://www.chiark.greenend.org.uk/~sgtatham/putty/

# Reference

[Magic Aliases: A Layering Loophole in the Bourne Shell][magic] (2003, by Simon Tatham)

(Simon Tatham is the author of [PuTTY]!)

# mquote (magic quote) - No more quoting headaches in Bash

## Usage

~~~
mquote [-dnpv] ...

  -d    Use "declare -p" for quoting.
  -n    Only print the command after quoting without executing it. This is
        implicit if there is no ``..`` in the argument.
  -p    Use "printf %q" for quoting.
  -v    Verbose. Print the command before execution.
~~~

## Note

* The `mquote` alias only works in ***interactive*** Bash shell.
* Bash `3.2+` is required.
* With Bash `4.4+`, `mquote` uses `${var@Q}` for quoting by default.
* In the following examples which use `ssh`, we assume the remote shell is also Bash.

## Examples

### Example 1: Quote a whole command

Say we have this demo command:

~~~
$ echo '111"222' | awk -F\" '{ print $1 + $2 }'
333
~~~

How should the command be quoted if we want to define it as an alias? Just pass the whole command **literally** to `mquote`:

~~~
$ mquote echo '111"222' | awk -F\" '{ print $1 + $2 }'
>>> 'echo '\''111"222'\'' | awk -F\" '\''{ print $1 + $2 }'\'''
~~~

Then, copy-n-paste the output to the `alias` command:

~~~
$ alias foo='echo '\''111"222'\'' | awk -F\" '\''{ print $1 + $2 }'\'''
$ foo
333
~~~

Or you can copy-n-paste the `mquote` output to a var assignment:

~~~
$ cmd='echo '\''111"222'\'' | awk -F\" '\''{ print $1 + $2 }'\'''
$ eval "$cmd"
333
$ ssh 127.0.0.1 "$cmd"
333
~~~

### Example 2: Pass a verbatim command through ssh

Still using this example:

~~~
$ echo '111"222' | awk -F\" '{ print $1 + $2 }'
333
~~~

To run it over ssh, we can ask `mquote` to automatically quote the command by using ``` ``..`` ```:

~~~
$ mquote ssh 127.0.0.1 ``echo '111"222' | awk -F\" '{ print $1 + $2 }'``
333
~~~

That's to say, `mquote` will automtically quote the part between ``` ``..`` ``` on the fly.

With `-v` (verbose) we can see the real command after quoting:

~~~
$ mquote -v ssh 127.0.0.1 ``echo '111"222' | awk -F\" '{ print $1 + $2 }'``
>>> ssh 127.0.0.1 'echo '\''111"222'\'' | awk -F\" '\''{ print $1 + $2 }'\'''
333
~~~

With `-n` (no run) it'll only print the command without executing it:

~~~
$ mquote -n ssh 127.0.0.1 ``echo '111"222' | awk -F\" '{ print $1 + $2 }'``
>>> ssh 127.0.0.1 'echo '\''111"222'\'' | awk -F\" '\''{ print $1 + $2 }'\'''
$ mquote -n -d ssh 127.0.0.1 ``echo '111"222' | awk -F\" '{ print $1 + $2 }'``
>>> ssh 127.0.0.1 "echo '111\"222' | awk -F\\\" '{ print \$1 + \$2 }'"
$ mquote -n -p ssh 127.0.0.1 ``echo '111"222' | awk -F\" '{ print $1 + $2 }'``
>>> ssh 127.0.0.1 echo\ \'111\"222\'\ \|\ awk\ -F\\\"\ \'\{\ print\ \$1\ +\ \$2\ \}\'
~~~

### Example 3: Pass a verbatim command through nested ssh

~~~
$ echo '111"222' | awk -F\" '{ print $1 + $2 }'
333
~~~

To run the above command with 2 level nested ssh (`ssh host1 ssh host2 ...`), we can use the ``` ``{2}..`` ``` syntax:

~~~
$ mquote -vd ssh 127.0.0.1 ssh 127.0.0.1 ``{2}echo '111"222' | awk -F\" '{ print $1 + $2 }'``
>>> ssh 127.0.0.1 ssh 127.0.0.1 "\"echo '111\\\"222' | awk -F\\\\\\\" '{ print \\\$1 + \\\$2 }'\""
333
~~~

For more levels quoting, use ``` ``{3}..`` ```, ``` ``{4}..`` ```, ...

~~~
$ mquote ssh 127.0.0.1 ssh 127.0.0.1 ssh 127.0.0.1 ``{3}echo '111"222' | awk -F\" '{ print $1 + $2 }'``
333
~~~

And ``` ``{1}..`` ``` is the same as ``` ``..`` ```.

### Example 4: Quote parameters for commands

Say we want to write an `echo` command which outputs `" ' # $( < > \ | )`. Just enclose it with ``` ``..`` ```:

~~~
$ mquote -v echo ``" ' # $( < > \ | )``
>>> echo '" '\'' # $( < > \ | )'
" ' # $( < > \ | )
~~~

Over ssh:

~~~
$ mquote ssh 127.0.0.1 echo ``{2}" ' # $( < > \ | )``
" ' # $( < > \ | )
$ mquote ssh 127.0.0.1 ssh 127.0.0.1 echo ``{3}" ' # $( < > \ | )``
" ' # $( < > \ | )
~~~

### Example 5: Multiple ``` ``..`` ``` in one command

~~~
$ mquote echo foo ``$( < > )`` bar ``" ' \ |``
foo $( < > ) bar " ' \ |
$ mquote ssh 127.0.0.1 echo foo ``{2}$( < > )`` bar ``{2}" ' \ |``
foo $( < > ) bar " ' \ |
~~~

### Example 6: It's never been so easy to write one-liners!

People often write `sed/awk/perl/...` one-liners and it's error-prone when quoting the
script part (usually `-e ...` or `-c ...`) in shell. With `mquote`, you can focus on
the util/language's script itself without worrying about shell quoting.

~~~
$ mquote perl -e ``print '"', "'", "\n"``
"'
$ mquote echo | sed -e ``s/.*/"'/``
"'
$ mquote awk ``BEGIN { print "\"" "'" }`` /dev/null
"'
$ mquote python3 -c ``print('"\'')``
"'
$ mquote perl -e ``print '"', "'", "\n"``
"'
$ mquote lua -e ``print("\"'")``
"'
$ mquote sh -c ``echo "\"'"``
"'
$ mquote echo | vim -u NONE -es ``+s/.*/"'/ | p | q!`` /dev/stdin
"'
~~~

# set-x

Quite often I need to turn on `set -x` to debug something:

~~~
$ set -x
$ do something
$ set +x

# or

$ set -x; do something; set +x
~~~

With `set-x` you can just `set-x do something`. For example:

~~~
$ sum=0; for ((i=1; i<=5; ++i)); do ((sum += i)); done; echo $sum
15
$ set-x sum=0; for ((i=1; i<=5; ++i)); do ((sum += i)); done; echo $sum
+ eval 'sum=0; for ((i=1; i<=5; ++i)); do ((sum += i)); done; echo $sum'
++ sum=0
++ (( i=1 ))
++ (( i<=5 ))
++ (( sum += i ))
++ (( ++i ))
++ (( i<=5 ))
++ (( sum += i ))
++ (( ++i ))
++ (( i<=5 ))
++ (( sum += i ))
++ (( ++i ))
++ (( i<=5 ))
++ (( sum += i ))
++ (( ++i ))
++ (( i<=5 ))
++ (( sum += i ))
++ (( ++i ))
++ (( i<=5 ))
++ echo 15
15
+ set 0
+ set +x
~~~
