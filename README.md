# pw_man, a password manager!

This is a light weight password manager I wrote to store my immense number of passwords locally, protected by a single password that I can remember (although it supports partitioning passwords into multiple ID's).

### Example
```
~ $ pw_man init
[... asks for password]
~ $ pw_man set aws
[Asks for aws password, then master password (that typed in above]
~ $ ps_man get aws # or just: ps_man aws
[Asks for master password then puts]
You have 10 seconds to use password 
```

### Security notice!
This is primarily used for website passwords that aren't security critical. It stores all the passwords for each ID in a single text file that is itself symmetrically encrypted. When adding a password, passwords are stored temporarily in a bash variable (local to function and overwritten after). When reading a password, they are placed in the clipboard for 10 seconds. 

You bee the judge if this is secure enough for you. For example, if your adversary could read the memory of your computer, they might find a password! Also, between typing the two needed passwords for saving a new password, the password file in unencrypted.

That being said, I find myself copy-pasting passwords anyway, and this is no less safe than that. It also prevents passwords from showing up in .bash_hisory (or .zsh_history for the winners). Lastly, the program is easily read to show all potential security risks and let you decide.

## Usage
```
Usage: pw_man [options] command [args]                                 

Options: -i <id> - use identity <id> instead of default                
         -h      - print this usage screen                             

Commands: init        - initialize pw_man for id <id>                  
          [get] <tag> - retrieve password for <tag>                    
          set <tag>   - set password for <tag>                         
          chpass      - change protective password for <id> 
```

## Installation 
Remember to change `.bashrc` to match your shell's rc file.
### Option 1
Sorry about the confusing quotes, but this should result in the correct quoting
for the RC file.
```
~/.../pw_man$ cp pw_man.sh pw_man
~/.../pw_man$ chmod +x pw_man
~/.../pw_man$ echo export PATH='"${PATH}':"$(pwd)"'"' >> ~/.bashrc
~/.../pw_man$ exec bash
```
### Option 2
Alternatively, you can remove the underscore from the name to make easier to 
type (e.g. alias pwman=...)
```
~/.../pw_man$ chmod +x pw_man.sh
~/.../pw_man$ echo "alias pw_man=$(pwd)/pw_man.sh" >> ~/.bashrc
~/.../pw_man$ exec bash
```
