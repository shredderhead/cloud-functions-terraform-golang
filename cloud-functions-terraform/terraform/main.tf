resource "google_storage_bucket" "default" {
  name          = "${var.app_name}-bucket-tfstate"
  force_destroy = false
  location      = "US"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}

provider "google" {
  project = "playground-projects-99323"
  region  = "europe-west1"
}

resource "google_storage_bucket" "bucket" {
  name     = "${var.app_name}-cloud-function-bucket" # This bucket name must be unique
  location = "us"
}

data "archive_file" "src" {
  type        = "zip"
  source_dir  = "${path.root}/../myfunction" # Directory where your Python source code is
  output_path = "${path.root}/../generated/workspace.zip"
}

resource "google_storage_bucket_object" "archive" {
  name   = "${data.archive_file.src.output_md5}.zip"
  bucket = google_storage_bucket.bucket.name
  source = "${path.root}/../generated/workspace.zip"
}

resource "google_cloudfunctions_function" "function" {
  name        = "${var.app_name}-scheduled-cloud-function"
  description = "An example Cloud Function that is triggered by a Cloud Schedule."
  runtime     = "go120"

  environment_variables = {
    FOO = "bar",
  }

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  trigger_http          = true
  entry_point           = "Handler" # This is the name of the function that will be executed in your code
}

resource "google_service_account" "service_account" {
  account_id   = "${var.app_name}-invoker-sa"
  display_name = "Cloud Function Tutorial Invoker Service Account"
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_service_account.service_account.email}"
}


resource "google_cloud_scheduler_job" "job" {
  name             = "${var.app_name}-cloud-fn-scheduler"
  description      = "Trigger the ${google_cloudfunctions_function.function.name} Cloud Function every 10 mins."
  schedule         = "*/5 * * * *" # every 5 mins
  time_zone        = "Europe/Dublin"
  attempt_deadline = "320s"

  http_target {
    http_method = "GET"
    uri         = google_cloudfunctions_function.function.https_trigger_url

    oidc_token {
      service_account_email = google_service_account.service_account.email
    }
  }
}
