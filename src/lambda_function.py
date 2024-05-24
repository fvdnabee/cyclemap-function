#!/usr/bin/env python3
"""Return cyclemap entries from mongodb."""
from dataclasses import dataclass
import json
import datetime
import os

import pymongo


def lambda_handler(event, context):
    """AWS lambda handler function."""
    if not event.get('rawPath', '/').startswith('/cyclemap_entries'):
        return {'statusCode': 404}

    try:
        args = parse_request(event)
    except ValueError as ex:
        return {'statusCode': 400, 'body': str(ex)}

    map_entries = get_cyclemap_entries(*args)

    return {'statusCode': 200, 'body': json.dumps(map_entries, default=_json_serial)}


def parse_request(event):
    """Parse cyclemap_entries request."""
    raw_path: str = event.get('rawPath', '/')

    if raw_path[-1] == '/':
        raw_path = raw_path[:-1]  # remove trailing slash

    segments = raw_path.split('/')
    if len(segments) != 8:
        raise ValueError('Client must provide seven path segments.')

    try:
        sw_lng, sw_lat = float(segments[2]), float(segments[3])
        ne_lng, ne_lat = float(segments[4]), float(segments[5])
    except ValueError as ex:
        raise ValueError("Invalid bbox.") from ex

    try:
        begin = datetime.datetime.fromisoformat(segments[6].replace("Z", "+00:00"))
        end = datetime.datetime.fromisoformat(segments[7].replace("Z", "+00:00"))
    except ValueError as ex:
        raise ValueError("Invalid time range.") from ex

    return BBox(sw_lng, sw_lat, ne_lng, ne_lat), begin, end


@dataclass
class BBox:
    """Geo bounding box."""
    sw_lng: float
    sw_lat: float
    ne_lng: float
    ne_lat: float


def get_cyclemap_entries(bbox: BBox, begin: datetime.datetime, end: datetime.datetime, client=None) -> list[dict]:
    """Return cyclemap entries from mongodb."""
    if client is None:
        client = _get_mongoclient()

    # Build the filter dict
    filt = {}
    filt['created_at'] = {
        '$gte': begin,
        '$lte': end
    }

    box = [(bbox.sw_lng, bbox.sw_lat), (bbox.ne_lng, bbox.ne_lat)]
    filt['location'] = {'$geoWithin': {'$box': box}}

    # Use aggregate lookup API instead of find, as it provides more functionality:
    aggr_dicts = []
    aggr_dicts.append({'$match': filt})

    # exclude _id field:
    aggr_dicts.append({'$project': {'_id': False}})

    return list(client.cyclemap_db.posts_collection.aggregate(aggr_dicts))


def _get_mongoclient():
    uri = os.getenv('MONGODB_URI', 'mongodb://localhost')
    return pymongo.MongoClient(uri)


def _json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""

    if isinstance(obj, (datetime.datetime, datetime.date)):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")
