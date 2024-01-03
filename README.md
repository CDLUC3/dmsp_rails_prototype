# DMSP Prototype application

This is the Rails 7 API application that supports the new DMSP UI.

It comproses the "Fargate" portion of this system diagram
<img src="docs/dmsp_prototype.png?raw=true">

## Development with Docker:

Prerequisites:
- Docker >= version 20.10
- Docker Compose >= version 2.23
- MySQL >= version 8.2
- [AWS NoSQL Workbench](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/workbench.settingup.html)

The local Docker development environment uses the `docker-compose.yaml` file along with a `.env` file that contains all of the environment variable config required to run the application.

Both the MySQL and DynamoDB databases are persisted between Docker container runs. The contents are stored in `docker/`. This directory is ignored by Git.

You will first need to make a copy of the `.env.example` file, `cp .env.example .env`, and then update it for your local system.

Once the `.env` file is in place you can build the docker environment (local dynamodb, mysql and Rails app) by running: `docker-compose up`

This will create a small local network running the 2 databases and the Rails application. It uses the `Dockerfile` which runs the `bin/docker-entrypoint` file to initialize the MySQL and NoSQL databases (if necessary) on startup.

**TODO:** For some reason the Rails app is starting before mysql has had a chance to finish starting up, so you have to manually start the app in the Docker desktop console once mysql is running.

Once the system is up and running, you can interact with it on port 8001. For example: `curl -v http://localhost:8001/tags`

### Other helpful commands for the local Docker development environment

Hop into one of the images in the container: `docker-compose exec mysql bash`

Tail the application logs: `docker-compose exec app tail -f ./log/docker.log`

Purge all records from the local NoSQL database: `docker-compose exec app bin/rails nosql:purge`

## Deploying to the AWS cloud

The Github repository has a corresponding branch for each of the environments except `docker`. When code is merged into the appropriate branch, an AWS CodePipeline is triggered which will run any tests and then build the Docker image within the AWS environment using the `buildspec.yaml` file.

The new image will then be picked up by AWS Fargate and deployed.

See the [dmp-hub-cfn repository](https://github.com/CDLUC3/dmp-hub-cfn) for the CodePipeline and CodeBuild defnitions

## Using another cloud provider

### Local development in Docker

You will most likely want to update the `docker-compose.yaml` file so that it resembles your own database resources.

### Adding new services to interact with cloud resources

All of the application's cloud provider specific code are defined in the `app/services/` directory. You will most likely need to create new subclasses of each service for your environment. For example, AWS uses an S3 bucket to store DMP PDF narrative documents. Your provider will have a different storage option.

To create your own storage service:
- Examine the contents of the service's directory (e.g. `app/services/nosql`) and you will notice that each contains a `factory.rb` and one or more other files.
- Find the abstract class(es) that act as interfaces and create your own copy for your environment. For example, `app/services/nosql/adapter.rb` and `app/services/nosql/item.rb` are the NoSQL abstract classes. You will notice that there are AWS specific expressions of these 2 classes. You can use them as a template.
- Once you've created your version(s) of the abstract class(es), you should add a new entry for your provider to the `factory.rb`
- Finally, examine the `config/initializers/dmsp_config.rb` file and update it to use your new services. Note that should NOT rename the constant names in this file. They are used throughout the application to find and use your services (e.g. `NOSQL_ITEM_CLASS = Nosql::AwsDynamodbItem`)

Note that you may need to do additional things within the local Docker environment config to get accurate representations of your cloud resources setup.

### Deploying
You will need to follow your cloud provider's instructions for it's CI/CD pipeline. We suggest creating your own version of the [dmsp_aws_prototype repository](https://github.com/CDLUC3/dmsp_aws_prototype) that is specific for your cloud provider.

This way you can keep any infrastructure as code logic for your environment together in one place and then add any necessary files to this repository to enable that build process. For example, the AWS CodePipleine uses the `buildspec.yaml` file.
