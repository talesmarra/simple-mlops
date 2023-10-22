import boto3
import json
import os
import pickle
import pandas as pd


def lambda_handler(event, context):
    print("event:\n ", event, "\n")
    # load body as json
    payload = json.loads(event['body'])

    # get the latest model tag from the registry
    table_name = 'simple-registry'
    dynamodb = boto3.resource('dynamodb')


    table = dynamodb.Table(table_name)

    response = table.scan()

    if 'Items' in response and len(response['Items']) > 0:
        # sort by id in reverse
        tag_value = sorted(response['Items'], key=lambda x: x['id'], reverse=True)[0]['tag']
        print("Latest_tag_value: ", tag_value)
    else:
        return {
            'statusCode': 404,
            'body': json.dumps('No models found')
            }  

    # Load the model from the registry bucket
    s3 = boto3.client('s3')
    model = s3.get_object(Bucket='registry-bucket-simple-ct', Key=f'model_{tag_value}.pkl')
    model = pickle.loads(model['Body'].read())
    # make predictions
    preds = model.predict(pd.DataFrame([payload]))[0]
    return {
        'statusCode': 200,
        'statusCode': 200,
        'body': json.dumps(str(preds))
    }