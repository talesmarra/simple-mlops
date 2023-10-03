import boto3
import json
import os
import pickle
import numpy as np


def lambda_handler(event, context):
    table_name = 'simple-registry'
    dynamodb = boto3.resource('dynamodb')


    table = dynamodb.Table(table_name)

    # Perform a query operation to retrieve the item with the max id
    response = table.query(
        Limit=1,
        ScanIndexForward=False,
        ProjectionExpression='tag'
    )
    if 'Items' in response and len(response['Items']) > 0:
        # Extract the tag from the item
        tag_value = response['Items'][0].get('tag')
        print(tag_value)
    else:
        return {
            'statusCode': 404,
            'body': json.dumps('No models found')
            }  

    # Load the model from the registry bucket
    s3 = boto3.client('s3')
    model = s3.get_object(Bucket='registry-bucket-simple-ct', Key=f'model_{tag_value}.pkl')
    model = pickle.loads(model['Body'].read())
    return {
        'statusCode': 200,
        'statusCode': 200,
        'body': json.dumps("OK")
    }