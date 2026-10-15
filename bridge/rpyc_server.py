import rpyc
from rpyc.utils.server import ThreadedServer

if __name__ == "__main__":
    t = ThreadedServer(rpyc.SlaveService, port=18812, hostname="0.0.0.0",
                       protocol_config={"allow_public_attrs": True,
                                        "allow_all_attrs": True,
                                        "sync_request_timeout": 60})
    t.start()
