# CHANGELOG for cookbook-openstack-identity

This file is used to list changes made in each version of cookbook-openstack-identity.

## 7.0.2:
### Bug
* Do not delete the sqlite database when node.openstack.db.identity.db_type is set to sqlite.
* Added `does not delete keystone.db when configured to use sqlite` test case for this scenario

## 7.0.1:
* Fixed <db_type>_python_packages issue when setting node.openstack.db.identity.db_type to sqlite.
* Added `converges when configured to use sqlite db backend` test case for this scenario.

## 7.0.0:
* Initial release of cookbook-openstack-identity.

- - -
Check the [Markdown Syntax Guide](http://daringfireball.net/projects/markdown/syntax) for help with Markdown.

The [Github Flavored Markdown page](http://github.github.com/github-flavored-markdown/) describes the differences between markdown on github and standard markdown.
