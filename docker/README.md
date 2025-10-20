# Docker Development Environment

This directory contains Docker configuration files for setting up a development environment for the textae_canvas application.

## Prerequisites

- Docker
- Docker Compose

## Quick Start

1. **Build and start the services:**
   ```bash
   cd docker
   docker-compose up -d
   ```

2. **Run the post-create script to initialize the environment:**
   ```bash
   docker-compose exec web bash /workspaces/textae_canvas/docker/post-create.sh
   ```

   This script will:
   - Install Ruby dependencies
   - Copy `.env.example` to `.env` (if it doesn't exist)
   - Set up the database
   - Create the Elasticsearch index

3. **Access the application:**
   - Application: http://localhost:3000
   - Elasticsearch: http://localhost:9200

## Manual Setup Steps

If you prefer to set up the environment manually:

1. **Start services:**
   ```bash
   docker-compose up -d
   ```

2. **Install dependencies:**
   ```bash
   docker-compose exec web bundle install
   ```

3. **Set up environment variables:**
   ```bash
   docker-compose exec web cp .env.example .env
   # Edit .env file to add your OpenAI API key
   ```

4. **Set up database:**
   ```bash
   docker-compose exec web bin/rails db:setup
   ```

5. **Create Elasticsearch index:**
   ```bash
   docker-compose exec web curl -X PUT "http://es:9200/smart_multilingual" -H "Content-Type: application/json" -d @./docker/es_index.json
   ```

6. **Start the Rails server:**
   ```bash
   docker-compose exec web bin/rails s -b 0.0.0.0 -p 3000
   ```

## Useful Commands

- **View logs:**
  ```bash
  docker-compose logs -f
  ```

- **Stop services:**
  ```bash
  docker-compose down
  ```

- **Stop services and remove volumes:**
  ```bash
  docker-compose down -v
  ```

- **Rebuild the web container:**
  ```bash
  docker-compose build web
  ```

- **Run Rails console:**
  ```bash
  docker-compose exec web bin/rails console
  ```

- **Run tests:**
  ```bash
  docker-compose exec web bin/rails test
  ```

## Configuration

### Environment Variables

The following environment variables are configured in `docker-compose.yml`:

- `RAILS_ENV`: Set to `development`
- `ELASTICSEARCH_HOST`: Set to `es:9200` (points to the Elasticsearch service)

Additional environment variables can be added to your `.env` file:

- `OPENAI_API_KEY`: Your OpenAI API key (required for AI annotation features)

### Volumes

- `esdata`: Persistent storage for Elasticsearch data
- `bundle`: Cache for Ruby gems (declared but not currently used)

### Services

#### web
- Rails application server
- Exposed on port 3000
- Depends on the `es` service

#### es
- Elasticsearch 8.15.3
- Exposed on port 9200
- Configured for single-node development
- Security features disabled for local development
- Memory limited to 512MB

## Troubleshooting

### Elasticsearch not starting
If Elasticsearch fails to start with memory errors, you may need to increase the Docker memory limit or adjust the `ES_JAVA_OPTS` setting in `docker-compose.yml`.

### Bundle install errors
If you encounter errors during `bundle install`, try rebuilding the container:
```bash
docker-compose down
docker-compose build --no-cache web
docker-compose up -d
```

### Port conflicts
If ports 3000 or 9200 are already in use, you can modify the port mappings in `docker-compose.yml`.
