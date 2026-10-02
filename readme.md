# oh-my-pi sandbox

## Installation

1. go to omp/agent and copy mcp.json.example to mcp.json and put in your context7 key
2. copy models.json.example to models.json and adjust your LLM server config
3. go back to the root, run `docker compose up -d`
4. after it is running, check `docker ps | grep omp` to find the omp sandbox container
5. run `docker exec -it CONTAINERID omp`
6. skip the cloud connection and follow the setup steps

## Multiple projects

Normally the dev folder would contain multiple projects, so you would likely want to enter via `docker exec -it CONTAINERID bash`, cd into your corresponding folder and then run omp from there. If you want to resume a previous session, use `omp --continue`

## Post-setup

Once you are in a project folder, you should instruct the agent to set up LSP servers for the project (such as typescript and go). For other languages you might need to include additional dependencies to the dockerfile.