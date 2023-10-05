
import os
import json
import pickle
import boto3

import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import f1_score
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline



CATEGORICAL_FEATURES = ['sex', 'smoker', 'region']
NUMERICAL_FEATURES = ['age', 'bmi', 'children']
BUCKET_NAME = "data-bucket-simple-ct"

def lambda_handler(event, context):
   # read file from s3 bucket
    s3 = boto3.client('s3')
    obj = s3.get_object(Bucket=BUCKET_NAME, Key='data.csv')
    df = pd.read_csv(obj['Body'])
    features = df.drop('charges', axis=1)
    target = (df['charges'] > 10000).astype(int)
    X_train, X_test, y_train, y_test = train_test_split(features, target, test_size=0.2, random_state=42)

    # define the preprocessing pipeline
    categorical_transformer = Pipeline(steps=[
        ('onehot', OneHotEncoder(handle_unknown='ignore'))
    ])
    numerical_transformer = Pipeline(steps=[
        ('scaler', StandardScaler())
    ])
    preprocessor = ColumnTransformer(
        transformers=[
            ('num', numerical_transformer, NUMERICAL_FEATURES),
            ('cat', categorical_transformer, CATEGORICAL_FEATURES)
        ])
    # define the model
    model = Pipeline(steps=[
        ('preprocessor', preprocessor),
        ('clf', LogisticRegression())
    ])
    # fit the model
    model.fit(X_train, y_train)
    # evluate the model with f1 score
    preds = model.predict(X_test)
    f1 = f1_score(y_test, preds)
    print(f'f1 score: {f1}')
    # generate a random SHA for the model
    model_sha = os.urandom(16).hex()
    # save the model to s3 bucket registry-bucket-simple-ct
    s3.put_object(Bucket='registry-bucket-simple-ct', Key=f'model_{model_sha}.pkl', 
                  Body=pickle.dumps(model), ContentType='application/octet-stream')

    # after deploying the registry you can write to dynamodb table
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('simple-registry')
    # insert the item with the fields id, published_at, tag, and evaluation metrics
    table.put_item(Item={
        'id': int(pd.Timestamp.now().timestamp()), 
        'published_at': pd.Timestamp.now().isoformat(),
        'tag': model_sha,
        'metrics': json.dumps({
            'f1_score': f1
        })})

    return {
        'statusCode': 200,
        'body': "Model trained successfully"
    }
