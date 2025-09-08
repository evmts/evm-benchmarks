#!/usr/bin/env python3
"""
Setup script for the CLI application.
"""
from setuptools import setup, find_packages

with open("requirements.txt") as f:
    requirements = f.read().splitlines()

setup(
    name="evm-bench",
    version="0.1.0",
    description="EVM Benchmark Runner - Run and analyze EVM performance benchmarks",
    author="Your Name",
    author_email="your.email@example.com",
    packages=find_packages(),
    install_requires=[],
    extras_require={
        "dev": requirements
    },
    entry_points={
        "console_scripts": [
            "evm-bench=src.cli:main",
        ],
    },
    python_requires=">=3.7",
    classifiers=[
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
)