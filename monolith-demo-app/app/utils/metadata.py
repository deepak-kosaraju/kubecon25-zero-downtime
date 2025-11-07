import os


def get_status_code_3xx_details():
    return {
        301: {
            "max_delay": 0.1,
            "message": "Moved Permanently",
            "description": "The requested resource has been permanently moved to a new location.",
        },
        302: {
            "max_delay": 0.1,
            "message": "Found",
            "description": "The requested resource has been found at a new location.",
        },
        304: {
            "max_delay": 0.1,
            "message": "Not Modified",
            "description": "The requested resource has not been modified since the last request.",
        },
    }


def get_status_code_4xx_details():
    return {
      400: {
          "max_delay": 0.1,
          "message": "Bad Request",
          "description": "The request was invalid.",
      },
      401: {
          "max_delay": 1.0,
          "message": "Unauthorized",
          "description": "The request was unauthorized.",
      },
      403: {
          "max_delay": 0.5,
          "message": "Forbidden",
          "description": "The request was forbidden.",
      },
      404: {
          "max_delay": 1.0,
          "message": "Not Found",
          "description": "The requested resource was not found.",
      },
      429: {
          "max_delay": 0.05,
          "message": "Too Many Requests",
          "description": "The request was throttled.",
      },
    }


def get_status_code_5xx_details():
    return {
        500: {
            "max_delay": 2.5,
            "message": "Internal Server Error",
            "description": "The server encountered an internal error.",
        },
        502: {
            "max_delay": 0.05,
            "message": "Bad Gateway",
            "description": "The server encountered a bad gateway.",
        },
        503: {
            "max_delay": 0.05,
            "message": "Service Unavailable",
            "description": "The server is currently unavailable.",
        },
        504: {
            "max_delay": 0.05,
            "message": "Gateway Timeout",
            "description": "The server encountered a gateway timeout.",
        },
    }


def get_pod_name():
    return os.getenv("POD_NAME")


def get_node_name():
    return os.getenv("POD_NODE_NAME")


def get_all_status_code_details():
    return {**get_status_code_3xx_details(), **get_status_code_4xx_details(), **get_status_code_5xx_details()}


def get_worker_id():
    return os.getpid()  # Get process ID to identify worker
