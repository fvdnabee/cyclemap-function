import datetime

import lambda_function


def test_get_cyclemap_entries():
    bbox = lambda_function.BBox(-180., -90., 180., 90.)
    begin = datetime.datetime(2017,
                              7,
                              1,
                              0,
                              0,
                              0,
                              tzinfo=datetime.timezone.utc)
    end = datetime.datetime(2022, 5, 24, 0, 0, 0, tzinfo=datetime.timezone.utc)
    entries = lambda_function.get_cyclemap_entries(bbox, begin, end)

    assert len(entries) > 0
    entry = entries[0]
    assert {
        'created_at', 'url', 'content', 'media_attachments', 'account',
        'location'
    } <= set(entry.keys())

    print('test_get_cyclemap_entries() succes')


if __name__ == '__main__':
    test_get_cyclemap_entries()
