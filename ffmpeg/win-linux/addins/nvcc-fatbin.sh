#!/bin/bash

ffbuild_dockeraddin() {
    to_df "ENV VMAF_CUDA_CODEGEN=nvcc NVCC_CCBIN=/usr/bin/g++"
}
