# Extending Drupal console

We have over 25 sites running off our Drupal 7 distribution and automate some of the tasks needed for development using a series of bash scripts. E.g.

- Check out the site’s repo
- Run drush make
- Run npm and grunt tasks
- Create symlinks
- Import databases
- Run updates

As we began looking towards Drupal 8, we looked for ways we could improve our development workflow and toolset, with a view towards improving efficiency and productivity. More specifically related to this post, improving the process of building a site on our VMs and environments, with as little manual work as possible. 

We decided to explore this using Drupal Console (https://drupalconsole.com/), which is a CLI tool to interact and debug Drupal websites. While it met most of our needs, we thought about extending it to allow the creation of global custom commands and use chain commands more easily.

# Initial investigation
To understand more about how Drupal Console works, I used the example shipped with Drupal Console to create a site configuration in the following location ~/.console/sites/.

File: *drupalvm.yml*
```javascript
dev:
  root: /var/www/drupalvm/drupal  
  host: 192.168.88.88
  user: vagrant
  password: vagrant
  console: /usr/local/bin/drupal
```

The above properties you can view by running site debug with the site name e.g. drupal site:debug drupalvm

I noticed that there were only few properties, and I was wondering if I could add more details about a site so that we could use Drupal Console to reduce the amount of commands our developers would need to type when building a site. E.g.instead of the following command  (git clone https://github.com/dennisinteractive/subscriptions.git --branch 8.x /var/www/subscriptions), use drupal site:checkout subscriptions


Drupal console doesn’t care what key/values you add, so I went on and created the yml file below with details about which repo to use, branch, database dump location, profile, etc.

<a name="file-subscriptions-yml">File:</a> *~/console/sites/subscriptions.yml
```javascript
dev:
  name: Subscriptions
  profile: config_installer
  root: /vagrant/repos/subscriptions
  host: subscriptions.vm8.didev.co.uk
  user: admin
  pass: demo
  repo:
    type: git
    url: https://github.com/dennisinteractive/subscriptions.git
    branch: 8.x
  db-dump: /mnt/nfs/Drupal/sql/d8_subscriptions-latest.sql.gz
```

In order to create some custom commands, I needed Drupal console to run globally. This requires it to be installed on my home folder, for my commands to be executed without the  need of having Drupal core installed.

Initially I tried to use the latest release 1.0.0-rc9, but things are moving too fast in Drupal console world. Since 1.0.0-beta5 lots had changed and some code from Drupal Console (https://github.com/hechoendrupal/DrupalConsole ) moved to separate  repos. e.g.

- Drupal Console Core https://github.com/hechoendrupal/drupal-console-core
- Drupal Console Launcher https://github.com/hechoendrupal/drupal-console-launcher

I was struggling to make my custom commands run globally using Drupal console launcher, I decided to branch off 1.0.0-beta5, get everything working, then port to the latest dev.
At the time one of the things that is definetely broken is the command site:new https://github.com/hechoendrupal/DrupalConsole/issues/2825.

With our development workflow in mind, I continued  to explore the following possibilities.

This is how we did it:

- [Using existing commands](#head-using-existing-commands)
- [Creating custom commands](#head-creating-custom-commands)
- [Using chains](#head-using-chains)
- [Chain calling another chain](#head-chain-calling-chain)

## 1. <a name="head-using-existing-commands">Using existing commands<a/>
<a name="cmd-site-new">**site:new**</a>
As I mentioned above I am using Drupal console 1.0.0-beta5, that still provides this command. The problem I encountered was that I could not  use a different Drupal project template, since the command would start a new site using **drupal-composer/drupal-project** as it was hard coded here https://github.com/hechoendrupal/DrupalConsole/blob/1.0.0-rc5/src/Command/Site/NewCommand.php#L99

So I implemented a new option to pass *--template* and issued a pull request (https://github.com/hechoendrupal/DrupalConsole/issues/2949), so the project template could be passed as parameter i.e. `drupal site:new /var/www/new --composer --template=dennisdigital/drupal-project`

**site:install**
This will install the site and append the database credentials to the bottom of settings.php. But our settings.php is committed to our repo and we really should not  commit these credentials. Apart from security concerns, they vary depending on the environment, i.e. CI, QA, Production.

So we placed these credentials into a separate file and then included it  in settings.php e.g.
File: web/sites/default/settings.php

File: *web/sites/default/settings.php*
```php
...
if (file_exists(__DIR__ . '/settings.db.php')) {
  include __DIR__ . '/settings.db.php';
}
```

File: *web/sites/default/settings.db.php*
```php
$databases['default']['default'] = array(
  'database' => 'subscriptions',
  'username' => 'root',
  'password' => '',
  'host' => '127.0.0.1',
  'port' => 3306,
  'driver' => 'mysql',
  'prefix' => '',
  'namespace' => 'Drupal\Core\Database\Driver\mysql',
);
```

**database:restore**
We store db dumps on a folder that is mounted and becomes accessible inside the VM. The files are stored in gzip format. This makes downloading the database for a site to our VMs faster, when working remotely. Our workflow also involves copying the file inside the VM, unzipping and then the importing. All of these steps cannot be handled by database:restore command, so we needed to think of another option to fulfill our needs.

One idea was  to only copy the dump from the server again, once there is a new dump available. i.e. reusing the same local copy of the zipped dump on subsequent database restores.

The two option we thought of were: 
- Forking Drupal console and sending a pull request with added functionality for the Drupal Console database:restore command.
- Creating our own Custom command.

I decided to go with the second option for now and if that worked, issue a pull request. Besides, at this stage I did not know if our requirements were relevant for the rest of the community.

## 2. <a name="head-creating-custom-commands">Creating Custom commands.</a>
After playing with built in commands I started looking into building our custom commands to fulfil our requirements, so we need the following:

- **site:checkout** After the new site has been installed and the codebase committed, we needed an easy way of running repo commands without having to type the repo’s URL every time. Instead of the copying and pasting that occurs when working across the many sites that we have, we thought about using information that is already available on the [site’s yml file](#file-subscriptions-yml)
- **site:compose** This will take care of running composer install/update
- **site:settings:db** This will take care of creating *settings.db.php* which will not be committed to the repo, but it will be inserted into *settings.php* as an include.
- **site:db:import** This is a replacement for *database:restore* with some additional features, mentioned above, such as support to zipped files.

I did some research and found that to make the commands available in Drupal console, we needed to list the classes in *~/.console/config.yml*. I have been chatting with [@jmolivas](https://twitter.com/jmolivas "@jmolivas")and at the time, there were plans to have these classes automatically registered as a service. See  https://github.com/hechoendrupal/DrupalConsole/issues/1947. 

But for now, the solution is to stick autowire at the bottom of *~/.console/config.yml*, i.e.
```javascript
...
# Custom commands
  autowire:
    commands:
      forced:
        _site_checkout:
          class: \VM\Console\Command\Develop\SiteCheckoutCommand
        _site_compose:
          class: \VM\Console\Command\Develop\SiteComposeCommand
```

Now the command appears in the list
`drupal list site`
![](https://github.com/dennisinteractive/drupal_console_commands/raw/gh-pages/images/drupal-list-site-checkout.png)

I implemented all commands from the list above but site:new. I came up with the idea of using chains to do it.

## 3. <a name="head-using-chains">Using chains</a>
Using chains to do what [*site:new*](#cmd-site-new) does makes the pull request above redundant, but on the other hand we don’t have to wait for it to be ported to Drupal console launcher. Also by using chains, we can eliminate some redundant code. 

File: *chain-site-new.yml*
```javascript
commands:
# Build from template
  - command: exec
    arguments:
      bin: 'composer create-project %{{project|dennisdigital/drupal-project:8.x-dev}}:%{{version|8.x-dev}} %{{directory|/vagrant/repos/new-site}} --stability dev --no-interaction'
I am using placeholders for project, version and directory, if the values are omitted when using interactive mode, the default values (after |) will be used.
```

But there was a problem: Chain commands need *--file* argument to specify which file to execute which is not very convenient. Imagine a developer wants to build a site using this chain, the command line would look like this:

`drupal chain --file=/some-folder/path-to-file/chain-site-new.yml`

I wanted to register chain commands using the same discovery mechanism as normal commands. Registering commands as a service is work in progress, but I needed some way of registering them in the interim.

Then I came up with the idea of creating a ChainRegister class https://github.com/dennisinteractive/DrupalConsole/blob/chain_register_beta5/src/Command/Chain/ChainRegister.php, which extends ChainCommand.

It has a mechanism similar to what we currently do with custom commands (above), where you basically list the classes in *~/.console/chain.yml* and the commands became available as normal commands.

This is a temporary solution until the work to register commands as services is finished.

File: *~/console/chain.yml*
```javascript
# Custom chains
chain:
  name:
    'site:new':
      file: '~/.config/composer/dev_scripts/vendor/dennisdigital/drupal_console_commands/config/chain/chain-site-new.yml'
    'site:new-install:
      file: '~/.config/composer/dev_scripts/vendor/dennisdigital/drupal_console_commands/config/chain/chain-site-new-install.yml'
```

### How it works
This will be loaded in the Application https://github.com/dennisinteractive/DrupalConsole/blob/chain_register_beta5/src/Application.php#L348 and passed to the constructor https://github.com/dennisinteractive/DrupalConsole/blob/chain_register_beta5/src/Command/Chain/ChainRegister.php

With very few modifications to ChainCommand.php, I introduced a new property $file and a check for $name in *configure()* https://github.com/dennisinteractive/DrupalConsole/blob/chain_register_beta5/src/Command/Chain/ChainCommand.php#L43.

That means, when you call chain commands the usual way with *--file*, the code will behave the same way as originally. But when the commands are passed via *ChainRegister* (chain.yml), $name and $file are passed via constructor and the *--file* is automatically done for you.

The chain commands will appear
`drupal list chain`
![](https://github.com/dennisinteractive/drupal_console_commands/raw/gh-pages/images/drupal-list-chain-site.png)

No need to specify *--file* anymore
`drupal chain:site:new`
![](https://github.com/dennisinteractive/drupal_console_commands/raw/gh-pages/images/chain-site-new.png)

On a hangout with [@jmolivas](https://twitter.com/jmolivas "@jmolivas") I pitched the idea and he liked it, this can be used in conjunction with commands as a service. I created a pull request that can be merged to the latest dev https://github.com/hechoendrupal/DrupalConsole/pull/2961. This pull request doesn’t use chain.yml, but for our branch off 1.0.0-beta5 it is still needed.

What if I want to create a chain that will do two things: Create a new site and run site install. That means calling chain:site:new and then site:install from this new chain.

## 4. <a name="head-chain-calling-chain">Chain calling another chain</a> (one may call it a “chain reaction”)
It kind of works out of the box. You can call other chain commands using exec, but you have to specify all the arguments and options as *--placeholder=”foo:bar”*  (each of them.) and It’s not pretty..

Imagine for example that we want to call chain-site-new.yml from another chain:

File: *chain-site-new-install.yml*
```javascript
# Run chain-site-new and site:install
commands:
  - command: exec
    arguments:
      bin: 'drupal chain --file=/some-folder/path-to-chains/chain/chain-site-new.yml --placeholder="project:%{{project|drupal-composer/drupal-project}}" --placeholder="version:%{{version|8.x-dev}}" --placeholder="directory:%{{directory|/var/www/site}}"'
  - command: site:install
    arguments:
      profile: %{{profile|standard}}
```
![](https://github.com/dennisinteractive/drupal_console_commands/raw/gh-pages/images/chain-site-new-install-file.png)

Note that chain-site-new-install.yml asks 4 questions and uses 3 arguments to call chain-site-new.yml and 1 argument to call site:install

With ChainRegister, this is how chain-site-new-install.yml would look
```javascript
# Run chain-site-new and site:install
commands:
  - command: chain:site:new
    options:
      placeholder:
        - 'project:%{{project|drupal-composer/drupal-project}}'
        - 'version:%{{version|8.x-dev}}'
        - 'directory:%{{directory|/var/www/site}}'
  - command: site:install
    arguments:
      profile: 'profile:%{{profile|standard}}'
```
![](https://github.com/dennisinteractive/drupal_console_commands/raw/gh-pages/images/chain-site-new-install.png)


### See it in action
Have a look at this article: [Development workflow with Drupal console](https://github.com/dennisinteractive/drupal_console_commands/blob/gh-pages/Development-workflow-drupal-console.md) where we introduce more custom commands and chains using ChainRegister.


## Roadmap
**database:restore**
Port the functionalities of *site:db:import*
Add option to specify the path for the dump i.e. **site.sql.gz**

**site:install**
Port the functionalities of *site:settings:db*
Add a new option to specify the filename to contain the db credentials, i.e. *settings.db.php*

**chain:site:new** will do the following:
- Build site using Drupal project template
- Create *~/.console/sites/site-name.yml* automatically
- Call the command to generate *settings.db.php*
- Run a site installation

**site:checkout**
- Pull the list of sites in the interactive mode, and a list of branches for the selected site: see `git ls-remote --heads <repo>`
- Add option for: tag
- Add option for: revision

**Chain commands**
When running chain commands within a site folder, don’t ask the site name, get it from the container.
Ability to call chain commands with arguments and options without having to specify *--placeholder* i.e. `--placeholder=”arg:foo” --placeholder=”option:bar”` would became `--option=bar`


## Related issues and Pull requests
- *site:new* has hard coded value for project template https://github.com/hechoendrupal/DrupalConsole/issues/2949 
- Chain is parsing comments https://github.com/hechoendrupal/DrupalConsole/pull/2963 
- Chain with *--no-interaction* is broken https://github.com/hechoendrupal/DrupalConsole/issues/2964 
- Using variables and functions in yml https://github.com/hechoendrupal/DrupalConsole/issues/2267 

## Repos
- Drupal Console https://github.com/hechoendrupal/DrupalConsole
- Dev scripts https://github.com/dennisinteractive/dev_scripts
- Drupal Console Commands: https://github.com/dennisinteractive/drupal_console_commands
- Drupal Project: https://github.com/dennisinteractive/drupal-project

## Issues
- Use Chain as actual command https://github.com/hechoendrupal/DrupalConsole/issues/1898
- Chain commands are not working when passing one placeholder and --no-interaction https://github.com/hechoendrupal/DrupalConsole/issues/2964

## Pull requests
- Chain Register: https://github.com/hechoendrupal/DrupalConsole/pull/2961
- Comments in yml: https://github.com/hechoendrupal/DrupalConsole/pull/2963

## Chat about Drupal console
- Drupal Console on Slack: https://drupal.slack.com/archives/drupal-console
- Drupal Console on Gitter: https://gitter.im/hechoendrupal/DrupalConsole

## About me

![](http://marcelovani.eu/images/me-350.jpg)

## Marcelo Vani
### Software engineer
[@marcelovani](https://twitter.com/marcelovani "@marcelovani")

[http://marcelovani.eu](http://marcelovani.eu)

### Dennis Publishing
![](http://cdn2.dennis.co.uk/sites/denniscorporate/themes/denniscorporate/logo.png)