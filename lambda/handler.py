import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
translate = boto3.client("translate")

def lambda_handler(event, context):
    try:
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = event['Records'][0]['s3']['object']['key']
        logger.info(f"Triggered by s3://{bucket}/{key}")

        # Download input JSON
        tmp_file = f"/tmp/{os.path.basename(key)}"
        s3.download_file(bucket, key, tmp_file)

        with open(tmp_file, "r", encoding="utf-8") as f:
            data = json.load(f)

        # Extract fields
        source = data.get("SourceLanguage")
        targets = data.get("TargetLanguages")
        texts   = data.get("Texts")

        # Normalize "Texts" so it always becomes a list
        if isinstance(texts, str):
            texts = [texts]

        if not source or not targets or not texts:
            raise ValueError("Input JSON must include SourceLanguage, TargetLanguages, and Texts")

        # Build translations
        translations = {}
        for target in targets:
            translated_list = []
            for text in texts:
                response = translate.translate_text(
                    Text=text,
                    SourceLanguageCode=source,
                    TargetLanguageCode=target
                )
                translated_list.append(response["TranslatedText"])
            translations[target] = translated_list

        # Output JSON
        output_data = {
            "SourceLanguage": source,
            "OriginalTexts": texts,
            "Translations": translations
        }

        output_key = f"translated_{os.path.basename(key)}"
        output_file = f"/tmp/{output_key}"

        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)

        # Upload to response bucket
        response_bucket = os.environ["RESPONSE_BUCKET"]
        s3.upload_file(output_file, response_bucket, output_key)
        logger.info(f"Uploaded result to s3://{response_bucket}/{output_key}")

        return {"status": "success", "file": output_key}

    except Exception as e:
        logger.error(f"Error processing file: {e}")
        raise
