#!/usr/bin/env python3
"""
Data Fetcher for Copilot Studio Azure AI Search Project

This script handles fetching data files from various sources (GitHub repository
or Azure Blob Storage) and placing them in a local directory for
subsequent processing by upload_data.py.

Supported sources:
1. GitHub repository (clones repo and extracts data from specified path)
2. Azure Blob Storage (downloads files from container/path)

File filtering:
- By default, fetches all files
- Use --file_pattern to filter by specific patterns (e.g., "*.pdf", "*.docx", "*.txt")
- Supports multiple patterns separated by commas

Usage:
    python fetch_data.py --source_type github --source_url <repo_url> --source_path data --output_dir ./local_data
    python fetch_data.py --source_type blob --source_url <blob_url> --source_path files --output_dir ./local_data
    python fetch_data.py --source_type github --source_url <repo_url> --source_path data --output_dir ./local_data --file_pattern "*.pdf,*.docx"
"""

import argparse
import fnmatch
import logging
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import List, Optional

from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
from azure.storage.blob import BlobServiceClient

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class DataFetcher:
    """
    Handles fetching data from various sources with proper error handling,
    retry logic, and security best practices.
    """

    def __init__(self, credential=None, file_patterns: Optional[List[str]] = None):
        """
        Initialize with Azure credential for blob operations and file patterns.

        Args:
            credential: Azure credential for blob operations
            file_patterns: List of file patterns to match (e.g., ['*.pdf', '*.docx'])
        """
        self.credential = credential or self._get_azure_credential()
        self.file_patterns = file_patterns or ["*"]  # Default to all files

    def _matches_pattern(self, filename: str) -> bool:
        """
        Check if filename matches any of the configured file patterns.

        Args:
            filename: Name of file to check

        Returns:
            True if file matches any pattern, False otherwise
        """
        for pattern in self.file_patterns:
            if fnmatch.fnmatch(filename.lower(), pattern.lower()):
                return True
        return False

    def _get_azure_credential(self):
        """Get appropriate Azure credential based on environment."""
        azure_client_id = os.environ.get("AZURE_CLIENT_ID")

        if azure_client_id:
            logger.info(f"Using managed identity with client ID: {azure_client_id}")
            return ManagedIdentityCredential(client_id=azure_client_id)
        else:
            logger.info("Using default Azure credentials")
            return DefaultAzureCredential()

    def fetch_from_github(
        self, repo_url: str, source_path: str, output_dir: str
    ) -> str:
        """
        Clone GitHub repository and extract files from specified path.

        Args:
            repo_url: GitHub repository URL
            source_path: Path within repository containing data files
            output_dir: Local directory to place fetched files

        Returns:
            Path to output directory containing fetched files
        """
        logger.info(f"Fetching data from GitHub repository: {repo_url}")
        logger.info(f"File patterns: {self.file_patterns}")

        # Ensure we're using the correct URL format for public repos
        if repo_url.startswith("https://github.com/") and not repo_url.endswith(".git"):
            repo_url = repo_url + ".git"

        with tempfile.TemporaryDirectory() as temp_dir:
            repo_path = os.path.join(temp_dir, "repo")

            try:
                # Clone repository (shallow clone for efficiency)
                logger.info(f"Cloning repository from: {repo_url}")

                # For public repositories, we can clone without credentials
                # First, try without any special authentication setup
                subprocess.run(
                    [
                        "git",
                        "clone",
                        "--depth",
                        "1",
                        "--single-branch",
                        "--no-tags",
                        repo_url,
                        repo_path,
                    ],
                    check=True,
                    capture_output=True,
                    text=True,
                    timeout=300,
                )

                logger.info("Repository cloned successfully")

                # Verify source path exists
                if source_path:
                    data_path = os.path.join(repo_path, source_path)
                    if not os.path.exists(data_path):
                        raise ValueError(
                            f"Source path '{source_path}' not found in repository"
                        )
                else:
                    data_path = repo_path

                # Copy matching files to output directory
                os.makedirs(output_dir, exist_ok=True)
                file_count = 0

                for file_path in Path(data_path).rglob("*"):
                    if file_path.is_file() and self._matches_pattern(file_path.name):
                        relative_path = os.path.relpath(file_path, data_path)
                        output_file = os.path.join(output_dir, relative_path)

                        # Create subdirectories if needed
                        os.makedirs(os.path.dirname(output_file), exist_ok=True)

                        # Copy file
                        shutil.copy2(file_path, output_file)
                        logger.info(f"Copied {relative_path}")
                        file_count += 1

                if file_count == 0:
                    logger.warning(
                        f"No files matching patterns {self.file_patterns} found in path '{source_path}'"
                    )
                else:
                    logger.info(f"Successfully fetched {file_count} files from GitHub")

                return output_dir

            except subprocess.TimeoutExpired:
                logger.error("Git clone timed out after 300 seconds")
                raise
            except subprocess.CalledProcessError as e:
                logger.error(f"Git clone failed with return code {e.returncode}")
                logger.error(f"stdout: {e.stdout}")
                logger.error(f"stderr: {e.stderr}")

                # Provide helpful error messages based on common issues
                if (
                    "could not read Username" in e.stderr
                    or "Authentication failed" in e.stderr
                ):
                    raise ValueError(
                        f"Failed to clone repository '{repo_url}': Authentication required. "
                        f"For public repositories like Azure-Samples/contoso-web, this should not happen. "
                        f"Please check if the repository URL is correct and accessible."
                    )
                elif "Repository not found" in e.stderr or "not found" in e.stderr:
                    raise ValueError(
                        f"Repository not found: '{repo_url}'. Please check the URL and ensure the repository exists and is accessible."
                    )
                elif "fatal: unable to access" in e.stderr:
                    raise ValueError(
                        f"Unable to access repository '{repo_url}'. This might be a network connectivity issue. "
                        f"Please ensure the deployment environment has internet access."
                    )
                else:
                    raise ValueError(
                        f"Failed to clone repository '{repo_url}': {e.stderr}"
                    )
            except Exception as e:
                logger.error(f"Error fetching from GitHub: {e}")
                raise

    def fetch_from_blob_storage(
        self, blob_url: str, source_path: str, output_dir: str
    ) -> str:
        """
        Download files from Azure Blob Storage.

        Args:
            blob_url: Azure Blob Storage container URL
            source_path: Path prefix within container (optional)
            output_dir: Local directory to place downloaded files

        Returns:
            Path to output directory containing downloaded files
        """
        logger.info(f"Fetching data from Azure Blob Storage: {blob_url}")
        logger.info(f"File patterns: {self.file_patterns}")

        try:
            # Parse blob URL to extract account and container
            url_parts = blob_url.rstrip("/").split("/")
            if len(url_parts) < 4:
                raise ValueError(f"Invalid blob URL format: {blob_url}")

            account_url = "/".join(
                url_parts[:3]
            )  # https://account.blob.core.windows.net
            container_name = url_parts[3]

            logger.info(f"Connecting to storage account: {account_url}")
            logger.info(f"Container: {container_name}")

            # Initialize blob service client
            blob_service_client = BlobServiceClient(
                account_url=account_url, credential=self.credential
            )
            container_client = blob_service_client.get_container_client(container_name)

            # List and download matching files
            prefix = source_path + "/" if source_path else ""
            blobs = container_client.list_blobs(name_starts_with=prefix)

            os.makedirs(output_dir, exist_ok=True)
            file_count = 0

            for blob in blobs:
                blob_filename = os.path.basename(blob.name)
                if self._matches_pattern(blob_filename):
                    # Calculate local file path
                    relative_path = (
                        blob.name.replace(prefix, "", 1) if prefix else blob.name
                    )
                    local_file_path = os.path.join(output_dir, relative_path)

                    # Create subdirectories if needed
                    local_dir = os.path.dirname(local_file_path)
                    if local_dir:
                        os.makedirs(local_dir, exist_ok=True)

                    # Download blob
                    blob_client = container_client.get_blob_client(blob.name)
                    with open(local_file_path, "wb") as download_file:
                        download_file.write(blob_client.download_blob().readall())

                    logger.info(f"Downloaded {relative_path}")
                    file_count += 1

            if file_count == 0:
                logger.warning(
                    f"No files matching patterns {self.file_patterns} found in the specified location"
                )
            else:
                logger.info(
                    f"Successfully fetched {file_count} files from blob storage"
                )

            return output_dir

        except Exception as e:
            logger.error(f"Error fetching from blob storage: {e}")
            raise


def main():
    """
    Main function to handle command line arguments and coordinate data fetching.
    """
    parser = argparse.ArgumentParser(
        description="Fetch data files from various sources",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Fetch Markdown files from Contoso web repository (default)
  python fetch_data.py --source_type github \\
    --source_url https://github.com/Azure-Samples/contoso-web.git \\
    --source_path public/manuals \\
    --output_dir ./local_data \\
    --file_pattern "*.md"

  # Fetch multiple file types from Azure Blob Storage
  python fetch_data.py --source_type blob \\
    --source_url https://mystorage.blob.core.windows.net/mycontainer \\
    --source_path documents \\
    --output_dir ./local_data \\
    --file_pattern "*.pdf,*.docx,*.txt"
        """,
    )

    parser.add_argument(
        "--source_type",
        required=True,
        choices=["github", "blob"],
        help="Type of data source",
    )

    parser.add_argument(
        "--source_url", help="Source URL (required for github and blob types)"
    )

    parser.add_argument(
        "--source_path",
        default="",
        help="Path within source containing data files (default: root)",
    )

    parser.add_argument(
        "--output_dir", required=True, help="Local directory to place fetched files"
    )

    parser.add_argument(
        "--file_pattern",
        default="*",
        help="File patterns to match, comma-separated (e.g., '*.pdf,*.docx,*.txt'). Default: '*' (all files)",
    )

    args = parser.parse_args()

    # Validate arguments
    if args.source_type in ["github", "blob"] and not args.source_url:
        parser.error(f"--source_url is required for source_type '{args.source_type}'")

    # Parse file patterns
    file_patterns = [
        pattern.strip() for pattern in args.file_pattern.split(",") if pattern.strip()
    ]
    if not file_patterns:
        file_patterns = ["*"]

    try:
        # Initialize data fetcher with file patterns
        fetcher = DataFetcher(file_patterns=file_patterns)

        # Fetch data based on source type
        if args.source_type == "github":
            result_path = fetcher.fetch_from_github(
                args.source_url, args.source_path, args.output_dir
            )
        elif args.source_type == "blob":
            result_path = fetcher.fetch_from_blob_storage(
                args.source_url, args.source_path, args.output_dir
            )
        else:
            raise ValueError(f"Unsupported source type: {args.source_type}")

        logger.info(
            f"Data fetching completed successfully. Files available at: {result_path}"
        )

    except Exception as e:
        logger.error(f"Data fetching failed: {e}")
        raise


if __name__ == "__main__":
    main()
