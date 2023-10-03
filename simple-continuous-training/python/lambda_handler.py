
import boto3
import pandas as pd
import os
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import f1_score
import pickle
import json

def preprocess_inputs(df):
    """ Preprocess the input data and returns the features ready for training
    :param df: the input data frame
    :return: the preprocessed features
    """

    # if this is the case has to go to premium plan
    y = (df['charges'] > 10_000).astype(int)
    one_hots = pd.get_dummies(df[['smoker', 'region', 'sex']])
    # concatenate the one-hot encoded columns with the age, bmi, and children columns
    X = pd.concat([df[['age', 'bmi', 'children']], one_hots], axis=1)
    return X, y


def train_model(X, y):
    """ Trains a logistic regression model and returns the trained model and the f1-score
    :param X: the input features
    :param y: the input labels
    """
    # split the data into train and test sets
    X_train, X_test, y_train, y_test = train_test_split(X, y, random_state=1)
    # train a linear regression model
    model = LogisticRegression()
    model.fit(X_train, y_train)
    # evaluate the model on the test using f1-score
    f1 = f1_score(y_test, model.predict(X_test))
    return model, f1


BUCKET_NAME = "data-bucket-simple-ct"
def lambda_handler(event, context):
   # read file from s3 bucket
    s3 = boto3.client('s3')
    obj = s3.get_object(Bucket=BUCKET_NAME, Key='data.csv')
    df = pd.read_csv(obj['Body'])
    X, y = preprocess_inputs(df)
    model, f1_score = train_model(X, y)
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
            'f1_score': f1_score
        })})

    return {
        'statusCode': 200,
        'body': "Model trained successfully"
    }