import boto3
import os

sns_client = boto3.client('sns')
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']  # Pass this via Lambda env variables

def lambda_handler(event, context):
    # Customize your message
    message = "A new file was uploaded or API was called!"
    
    response = sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=message,
        Subject='Notification from your system'
    )
    
    print(f"Message sent to SNS: {response['MessageId']}")
    
    return {
        'statusCode': 200,
        'body': 'Notification sent successfully'
    }
