# syntacticus-api

This is the backend API for syntacticus.org. It only contains the code for serving the API.

The exposed API is not meant for public consumption. If you want to use any of the data on syntacticus.org for your own projects download the raw data files from the upstream treebank projects.

To configure and test

```sh
bundle
bundle exec rspec
```

To run in production

```sh
SECRET_KEY_BASE=<my-key> bin/rails s -e production -p 3456
```
