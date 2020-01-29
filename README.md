# aws-sqs
SDK for AWS SQS 

## SendMessage
https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_SendMessage.html
```
Sqs.SendMessage('us-west-2','xxxxxxx','my_queue','Hello');
```

## SendMessageBatch
https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_SendMessageBatch.html
```
List<String> messages = new List<String>{'Hello','Bonjour','Ciao'};
Sqs.SendMessageBatch('us-west-2','xxxxxxx','my_queue',messages);
```

## SQS creation
![alt text](https://user-images.githubusercontent.com/10975944/73140626-4ae68d80-407b-11ea-97fb-fac56e7ff6d8.png)
