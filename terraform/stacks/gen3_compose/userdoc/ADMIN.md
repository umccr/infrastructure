# Admin Tasks

## POC Setup

- It is then front-ed by Route53 + ACM SSL certificate with ALB -- [Application Load-Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html). See corresponding [terraform stack](https://github.com/umccr/infrastructure/tree/master/terraform/stacks/gen3_compose) for details.
- At the moment, this EC2 instance is created manually through Console, and has Name tag "**gen3_compose**".
- Hibernate the EC2 instance when not in use.

## Working with Stack

```
aws sso login --profile dev
aws ssm start-session --profile dev --target {check-instance-id-in-ec2-console}
sudo su ec2-user
cd /opt/gen3/compose-services/
docker-compose ps
docker-compose ps --services
docker-compose ps --services | wc -l
16
```

- Bring up the stack
```
docker-compose up -d
```

- Bring down the stack
```
docker-compose down
```

- Check `fence-service` log
```
docker logs fence-service
```

- Tail `fence-service` log
```
docker logs fence-service -f
(ctrl+c to exit)
```

- Gen3 also compiles [Docker compose services cheat sheet](https://github.com/uc-cdis/compose-services/blob/master/docs/cheat_sheet.md)
- At the point, we have pretty much done up to what describe in:
    - https://gen3.org/resources/operator/index.html
    - https://github.com/uc-cdis/compose-services/blob/master/README.md

## Admin, ACL and User

- Gen3 has no administration configuration web UI or the like. Configurations are somewhat define in a couple of YAML files that sit under `Secrets` sub-directory. i.e. on our EC2 instance at this location: `/opt/gen3/compose-services/Secrets`.

- At least, you may wish to observe `user.yaml` which entails ACL on resources.
```
cd /opt/gen3/compose-services
less Secrets/user.yaml
(space bar to scroll; q to quit)
``` 

- When this `user.yaml` is modified, it has to reload `fence-service` then sync the new user settings as follows:
```
docker-compose restart fence-service
docker exec -it fence-service fence-create sync --arborist http://arborist-service --yaml user.yaml
```

- Also made a snapshot `user.yaml` copy here, for convenience. It may be outdated. But just to get the idea. 

## Database Backend

- Gen3 use PostgreSQL and ElasticSearch for persistent data stores. 
- Web admin interface [pgAdmin4](https://www.pgadmin.org) and [kibana](https://www.elastic.co/kibana) available respectively for accessing these persistent stores for convenience.

> 🙋‍♂️ Please ask login cred on pgAdmin4/kibana in Slack `#gen3`.

#### pgAdmin4

- https://gen3.dev.umccr.org/pgadmin4/

![pgAdmin4.png](img/pgAdmin4.png)


#### kibana

- https://gen3.dev.umccr.org/kibana/

![kibana.png](img/kibana.png)
