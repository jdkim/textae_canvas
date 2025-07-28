# Annotation Canvas
## Environment
- Ruby 3.4.4
- Rails 8.0.2
- SQLite3 2.6.0

## Installation
### Clone repository
```
git clone https://github.com/jdkim/textae_canvas.git
cd textae_canvas
```

### Install dependencies
```
bundle install
```

### Setup database
```
rails db:setup
```

### Set OpenAI API key to environment variable
Create .env file and set the API key as below
```
OPENAI_API_KEY="Your api key here"
```

To obtain your api key, follow the OpenAI API key creation procedure below.

### Start the server
```
rails server
```

Now, you can access Annotation Canvas at http://localhost:3000.

## OpenAI API key creation procedure
### Step 1
API keys can be obtained from the OpenAI platform. Must be logged in.
```
https://platform.openai.com/api-keys
```

### Step 2
Click `+ Create new secret key` button on API keys page and generate secret key.   
The API key will be displayed immediately after creation, so please copy and keep it. Once this screen is closed, it cannot be displayed again.

### Step 3
Creation can be done without registering payment information, but you will need to purchase API credits to use the API.   
Move to billing page, set payment details and purchase credits.
```
https://platform.openai.com/settings/organization/billing/overview
```
