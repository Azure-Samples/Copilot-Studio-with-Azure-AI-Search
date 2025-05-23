"""Common utility functions for the search module."""

import argparse
from urllib.parse import urlparse

def absolute_url(value):
    """
    Validate that the input is an absolute URL with a valid scheme and netloc.

    Args:
        value (str): The URL to validate.
    Raises:
        argparse.ArgumentTypeError: If the URL is not absolute or does not have a valid scheme and netloc.
    Returns:
        str: The validated absolute URL.
    """
    parsed = urlparse(value)
    # Check if the scheme and netloc are present
    if not parsed.scheme or not parsed.netloc:
        raise argparse.ArgumentTypeError(f"'{value}' is not a valid absolute URL")
    return value

def valid_name(value):
    """
    Validate that the input is a valid name that may include alphanumeric symbols, "-" or "_".
    The method doesn't check a specific length and case.

    Args:
        value (str): The name to validate.
    Raises:
        argparse.ArgumentTypeError: If the name is empty, contains only whitespace, or has invalid characters.
    Returns:
        str: The validated name.
    """
    if not value or not value.strip():
        raise argparse.ArgumentTypeError(f"'{value}' is not a valid name")
    parsed_value = value.replace("-", "").replace("_", "")
    if not parsed_value.isalnum():
        raise argparse.ArgumentTypeError(f"'{value}' contains invalid characters. Look at the documentation for naming conventions.")
    return value
