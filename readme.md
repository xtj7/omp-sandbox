# oh-my-pi sandbox

## Installation

1. copy mcp.json.example to mcp.json and put in your context7 key
2. copy models.json.example to models.json and adjust your LLM server config
3. run `docker compose up -d`
4. after it is running, check `docker ps | grep omp` to find the omp sandbox container
5. run `docker exec -it CONTAINERID omp`
6. skip the cloud connection and follow the setup steps

