#include <cuda_runtime.h>
#include <cfloat>
#include <cstdint>
#include "../include/gpu.h"

cudaStream_t CUDASTREAM = nullptr;

// __global__ void rgbToTensor(unsigned char *input, float *output, uint32_t width, uint32_t height)
// {
//     int x = blockIdx.x * blockDim.x + threadIdx.x;
//     int y = blockIdx.y * blockDim.y + threadIdx.y;
//     if (x < width && y < height + 160)
//     {
//         int idx_out = (y * width + x);
//         int size_out = width * (height + 160);
//         if (y < height + 80 && y >= 80)
//         {
//             int idx_in = 3 * ((y - 80) * width + x);
//             output[idx_out] = input[idx_in] / 255.0f;                    // R
//             output[idx_out + size_out] = input[idx_in + 1] / 255.0f;     // G
//             output[idx_out + 2 * size_out] = input[idx_in + 2] / 255.0f; // B
//         }
//         else
//         {
//             output[idx_out] = 0.5f;                // R
//             output[idx_out + size_out] = 0.5f;     // G
//             output[idx_out + 2 * size_out] = 0.5f; // B
//         }
//     }
// }

// __global__ void rgbToTensor(uint8_t *input, float *output)
// {
//     int x = blockIdx.x * blockDim.x + threadIdx.x;
//     int y = blockIdx.y * blockDim.y + threadIdx.y;
//     if (x < 640 && y < 640)
//     {
//         int idx_out = (y * 640 + x);
//         int size_out = 640 * 640;
//         if (y < 560 && y >= 80)
//         {
//             int idx_in = 3 * ((y - 80) * 640 + x);
//             output[idx_out] = input[idx_in] / 255.0f;                    // R
//             output[idx_out + size_out] = input[idx_in + 1] / 255.0f;     // G
//             output[idx_out + 2 * size_out] = input[idx_in + 2] / 255.0f; // B
//         }
//         else
//         {
//             output[idx_out] = 0.5f;                // R
//             output[idx_out + size_out] = 0.5f;     // G
//             output[idx_out + 2 * size_out] = 0.5f; // B
//         }
//     }
// }

__global__ void rgbToTensor(uint8_t *input, float *output, uint32_t width, uint32_t height)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x < width && y < height)
    {
        int idx_out = (y * width + x);
        int size_out = width * height;
        int idx_in = 3 * idx_out;

        output[idx_out] = input[idx_in] / 255.0f;                    // R
        output[idx_out + size_out] = input[idx_in + 1] / 255.0f;     // G
        output[idx_out + 2 * size_out] = input[idx_in + 2] / 255.0f; // B
    }
}

__global__ void rgbToTensorWithPadding(uint8_t *input, float *output, uint32_t width, uint32_t height, uint32_t target_width, uint32_t target_height, uint32_t padding_w, uint32_t padding_h)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x < target_width && y < target_height)
    {
        int idx_out = (y * target_width + x);
        int size_out = target_height * target_width;
        if (x < padding_w || x >= width + padding_w || y < padding_h || y >= height + padding_h)
        {
            output[idx_out] = 0.5f;                // R
            output[idx_out + size_out] = 0.5f;     // G
            output[idx_out + 2 * size_out] = 0.5f; // B
        }
        else
        {
            int idx_in = 3 * idx_out;
            output[idx_out] = input[idx_in] / 255.0f;                    // R
            output[idx_out + size_out] = input[idx_in + 1] / 255.0f;     // G
            output[idx_out + 2 * size_out] = input[idx_in + 2] / 255.0f; // B
        }
    }
}

uint16_t convert_rgb888_3dtensor_with_padding(uint8_t *input, float *output, uint32_t width, uint32_t height, uint32_t target_width, uint32_t target_height)
{
    dim3 thread_per_block(32, 32);
    dim3 num_blocks((target_width + 31) / 32, (target_height + 31) / 32);
    uint32_t padding_x = 0, padding_y = 0;
    if (width < target_width)
    {
        padding_x = (target_width - width) / 2;
    }
    if (height < target_height)
    {
        padding_y = (target_height - height) / 2;
    }
    rgbToTensorWithPadding<<<num_blocks, thread_per_block>>>(input, output, width, height, target_width, target_height, padding_x, padding_y);
    check_status(cudaDeviceSynchronize());
    return (uint16_t)cudaSuccess;
}

// assume that input is (640, 480, 3)
// output is (3, 640, 480)
// only normalize
uint16_t convert_rgb888_3dtensor(uint8_t *input_buffer, float *output_buffer, uint32_t width, uint32_t height)
{
    dim3 threads_per_block(32, 32);
    dim3 num_blocks((width + 31) / 32, (height + 31) / 32);
    // rgbToTensor<<<num_blocks, threads_per_block, 0, CUDASTREAM>>>(input_buffer, output_buffer);
    // cudaStreamSynchronize(CUDASTREAM);
    rgbToTensor<<<num_blocks, threads_per_block>>>(input_buffer, output_buffer, width, height);
    check_status(cudaDeviceSynchronize());
    return (uint16_t)cudaSuccess;
}

uint16_t transfer_host_to_host(uint8_t *dst, uint8_t *src, uint32_t size)
{
    check_status(cudaMemcpy(dst, src, size, cudaMemcpyHostToHost));
    return (uint16_t)cudaSuccess;
}

uint16_t transfer_host_to_device(uint8_t *host_mem, uint8_t *device_mem, uint32_t size)
{
    check_status(cudaMemcpy(device_mem, host_mem, size, cudaMemcpyHostToDevice));
    return (uint16_t)cudaSuccess;
}

uint16_t transfer_device_to_host(uint8_t *host_mem, uint8_t *device_mem, uint32_t size)
{
    check_status(cudaMemcpy(host_mem, device_mem, size, cudaMemcpyDeviceToHost));
    return (uint16_t)cudaSuccess;
}

uint16_t cuda_malloc(uint32_t size, uint8_t **buffer)
{
    check_status(cudaMalloc((void **)buffer, size));
    check_status(cudaMemset((void *)*buffer, 0x0, size));
    return (uint16_t)cudaSuccess;
}

uint16_t cuda_malloc_host(uint32_t size, uint8_t **buffer)
{
    check_status(cudaMallocHost((void **)buffer, size));
    check_status(cudaMemset((void *)*buffer, 0x0, size));
    return (uint16_t)cudaSuccess;
}

uint16_t cuda_malloc_managed(uint32_t size, uint8_t **buffer)
{
    check_status(cudaMallocManaged((void **)buffer, size));
    check_status(cudaMemset((void *)*buffer, 0x0, size));
    return (uint16_t)cudaSuccess;
}

uint16_t cuda_free(uint8_t *buffer)
{
    check_status(cudaFree(buffer));
    return (uint16_t)cudaSuccess;
}

uint16_t cuda_free_host(uint8_t *buffer)
{
    check_status(cudaFreeHost(buffer));
    return (uint16_t)cudaSuccess;
}

uint16_t init_cuda()
{
    check_status(cudaStreamCreate(&CUDASTREAM));
    return (uint16_t)cudaSuccess;
}

uint16_t destroy_cuda()
{
    check_status(cudaStreamDestroy(CUDASTREAM));
    return (uint16_t)cudaSuccess;
}