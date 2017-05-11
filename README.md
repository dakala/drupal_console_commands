# Drupal console commands

Provides custom Drupal console commands and chains.

## Requirements
- Composer https://getcomposer.org/
- Drupal console https://drupalconsole.com/

## Installation

curl -L https://goo.gl/UnjUuW | sh

# Commands
These are custom commands used to build a site. The information about the site comes from ~/.console/sites/site-name.yml.
e.g. https://raw.githubusercontent.com/dennisinteractive/drupal_console_commands/master/example/site-example.yml

- drupal **site:new**
	Builds a new site using Drupal project as template https://github.com/dennisinteractive/drupal-project
- drupal **site:checkout** *site-mame* --
	Performs a git clone and checks out the specified branch
- drupal **site:compose** *site-name*
	Runs *composer install*. Alternatively, it will run *composer update* if there is a composer.lock.
- drupal **site:settings:db** *site-name*
	Creates *settings.db.php* in the *web/sites/default* folder. This file contains DB credentials and should not be committed.
- drupal **site:settings:local** *site-name*
	Creates *settings.local.php* in the *web/sites/default* folder. This file contains local settings overrides and should not be committed.
- drupal **site:settings:memcache** *site-name*
	Creates *settings.memcache.php* in the *web/sites/default* folder. This file contains Memcache configuration and should not be committed.
- drupal **site:phpunit:setup** *site-name*
	Creates *phpunit.xml* in the root. This file contains PHPUnit configuration and should not be committed.
- drupal **site:behat:setup** *site-name*
	Creates *behat.yml* in the *tests* folder. This file contains Behat configuration and should not be committed.
- drupal **site:db:import** *site-name*
	If a database dump is available, it will drop the current database and import the dump. The db-dump information comes from *~/.console/sites/site-name.yml*.
	The command will copy the dump from the original place to */tmp*. If you run the command again, it will only copy the file once the original has changed. This is very useful when working remotely on slow networks.
	If no db-dump information is available or there is no dump at the location, it will run a site install.
	Supported extensions: **.sql**, **.sql.gz**.
- drupal **site:build**
	A chain that will call all the commands below:
    - site:checkout
    - site:rebuild
- drupal **site:rebuild**
	A chain that will call all the commands below:
    - site:compile
    - site:configure
    - site:db:import
    - site:construct
- drupal **site:rebuild-prod**
	A chain that will call all the commands below:
    - site:compile
    - site:construct
- drupal **site:npm**
  Runs NPM.
- drupal **site:grunt**
  Runs Grunt.
- drupal **site:compile**
	A chain that will call all the commands below:
    - site:compose
    - 'exec' command that runs npm in supported directories.
    - 'exec' command that runs grunt in supported directories.
- drupal **site:configure**
	A chain that will call all the commands below:
    - site:settings:db
    - site:settings:local
    - site:settings:memcache
- drupal **site:construct**
	A chain that will call all the commands below:
    - 'exec' command that clears drupal caches.
    - 'exec' command that sets drush aliases.
    - 'exec' command that runs drupal updates.
    - 'exec' command that imports drupal config twice.
    - 'exec' command that clears drupal caches.
- drupal **site:test**
	A chain that will call all the commands below:
    - site:phpunit:setup
    - site:behat:setup
    - 'exec' command that runs behat tests.
    - 'exec' command that runs phpunit tests.

# Useful arguments and options
- **-h** Show all the available arguments and options
- **--no-interaction** Will execute the command without asking any optional argument

# Environment variables
By default, the commands will use parameters from the site.yml, but it is possible to override them using environment variables.

For example, to override the root directory you can set the variable before calling `site:build`

`export site_destination_directory="/directory/"`

# Usage example
```
drupal site:build
drupal site:db:import [site_name]
```
