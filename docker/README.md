# Docker Development Environment

This directory contains Docker configuration files for setting up a development environment for the Annotation Canvas application.

## Prerequisites

- Docker
- Docker Compose

## Quick Start

1. **Build and start the services:**
   ```bash
   cd docker
   docker compose up -d
   ```

2. **Add environment variables to your `.env` file:**

   - `OPENAI_API_KEY`: Your OpenAI API key
   - `GOOGLE_CLIENT_ID`: Your Google OAuth2 client ID
   - `GOOGLE_CLIENT_SECRET`: Your Google OAuth2 client secret
   - `LLM_SERVICE_BASE_URL`: LLM service base URL (default: http://localhost:3000)

3. **Run the post-create script to initialize the environment:**
   ```bash
   docker compose exec web bash /workspaces/textae_canvas/docker/post-create.sh
   ```

   This script will:
   - Install Ruby dependencies
   - Copy `.env` to `.env` (if it doesn't exist)
   - Set up the database
   - Create the Elasticsearch index

4. **Access the application:**
   - Application: http://localhost:3000

## Useful Commands

- **View logs:**
  ```bash
  docker compose logs -f
  ```

- **Stop services:**
  ```bash
  docker compose down
  ```

- **Stop services and remove volumes:**
  ```bash
  docker compose down -v
  ```

- **Rebuild the web container:**
  ```bash
  docker compose build web
  ```

- **Run Rails console:**
  ```bash
  docker compose exec web bin/rails console
  ```

- **Run tests:**
  ```bash
  docker compose exec web bin/rails test
  ```

## Configuration

### Environment Variables

The following environment variables are configured in `docker compose.yml`:

- `RAILS_ENV`: Set to `development`
- `ELASTICSEARCH_HOST`: Set to `es:9200` (points to the Elasticsearch service)

Additional environment variables can be added to your `.env` file:

- `OPENAI_API_KEY`: Your OpenAI API key (required for AI annotation features)
- `GOOGLE_CLIENT_ID`: Your Google OAuth2 client ID (required for authentication)
- `GOOGLE_CLIENT_SECRET`: Your Google OAuth2 client secret (required for authentication)
- `LLM_SERVICE_BASE_URL`: LLM service base URL (default: http://localhost:3000)

### Volumes

- `esdata`: Persistent storage for Elasticsearch data
- `bundle`: Reserved for future use (not currently mounted)

