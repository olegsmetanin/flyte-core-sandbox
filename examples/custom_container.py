from flytekit import ImageSpec
from flytekit import task, workflow

custom_image = ImageSpec(
   name="flytekit",  # default docker image name.
   tag_format="{spec_hash}",
   base_image="ghcr.io/flyteorg/flytekit:py3.11-1.10.2",  # the base image that flytekit will use to build your image.
   packages=["pandas"],  # python packages to install.
   registry="registry.docker-registry.svc.cluster.local:5000", # the registry your image will be pushed to.
   python_version="3.11"
)

@task(container_image=custom_image)
def say_hello(name: str) -> str:
    return f"Hello, {name}!"

@workflow
def custom_container_wf(name: str = 'world') -> str:
    res = say_hello(name=name)
    return res

if __name__ == "__main__":
    print(f"Running wf() {custom_container_wf(name='passengers')}")