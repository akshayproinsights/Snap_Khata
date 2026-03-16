import os
import json
import logging
from typing import List

logger = logging.getLogger(__name__)

def enqueue_process_invoices_task(
    task_id: str,
    file_keys: List[str],
    r2_bucket: str,
    username: str,
    force_upload: bool = False
) -> bool:
    """
    Enqueues a task to process invoices in the background via Google Cloud Tasks.
    """
    try:
        from google.cloud import tasks_v2
    except ImportError:
        logger.error("google-cloud-tasks library is not installed.")
        return False

    project = os.getenv('GCP_PROJECT_ID')
    location = os.getenv('GCP_REGION', 'us-central1')
    queue = os.getenv('CLOUD_TASKS_QUEUE_NAME', 'invoice-processing-queue')
    base_url = os.getenv('CLOUD_RUN_SERVICE_URL', '').rstrip('/')
    service_account_email = os.getenv('CLOUD_TASKS_OIDC_SERVICE_ACCOUNT')

    if not all([project, location, queue, base_url, service_account_email]):
        error_msg = f"Missing required environment variables for Cloud Tasks. project={project}, location={location}, queue={queue}, base_url={base_url}, service_account={service_account_email}"
        logger.error(error_msg)
        return False

    url = f"{base_url}/api/upload/internal/process-task"

    client = tasks_v2.CloudTasksClient()
    parent = client.queue_path(project, location, queue)

    payload = {
        "task_id": task_id,
        "file_keys": file_keys,
        "r2_bucket": r2_bucket,
        "username": username,
        "force_upload": force_upload
    }

    task = {
        "http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "url": url,
            "headers": {"Content-type": "application/json"},
            "body": json.dumps(payload).encode(),
            "oidc_token": {
                "service_account_email": service_account_email,
                "audience": url,
            },
        }
    }

    try:
        response = client.create_task(request={"parent": parent, "task": task})
        logger.info(f"Created Cloud Task: {response.name} for task_id: {task_id}")
        return True
    except Exception as e:
        logger.error(f"Failed to create Cloud Task for task_id {task_id}: {e}")
        return False
