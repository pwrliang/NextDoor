__device__ __host__ inline EdgePos_t vertex_sample_set_start_pos_fixed_size (const CSRPartition* root_partition, VertexID vertex) 
{
  assert (root_partition->has_vertex(vertex));
  return vertex-root_partition->first_vertex_id;
}

//#define USE_PARTITION_FOR_SHMEM_1
//#define EDGES_IN_SHM_MEM

#ifdef EDGES_IN_SHM_MEM
  #ifndef USE_PARTITION_FOR_SHMEM_1
    #error "EDGES_IN_SHM_MEM defined but not USE_PARTITION_FOR_SHMEM_1"
  #endif
#endif
__global__ void run_hop_parallel_single_step_device_level_fixed_size (int N_HOPS, int hop, 
              CSRPartition* csr,
              CSRPartition* root_partition,
              VertexID* embeddings_additions, 
              EdgePos_t num_neighbors,              
              EdgePos_t* previous_stage_filled_range,
              VertexID* thread_to_src,
              VertexID* thread_to_roots,
              VertexID* grid_level_thread_to_linear_thread_map,
              EdgePos_t total_roots,
              EdgePos_t start_linear_id,
              EdgePos_t src_num_roots,
              EdgePos_t linear_threads_executed,
              const RandNumGen* rand_num_gen,
              Sampler* samplers)
{
#ifdef USE_PARTITION_FOR_SHMEM_1
  __shared__ EdgePos_t src_num_edges;
  __shared__ VertexID hop_vertex;
  __shared__ EdgePos_t start_edge_idx;
#else
  VertexID hop_vertex;
  EdgePos_t start_edge_idx;
#endif

  int device_level_thread_id = blockIdx.x*blockDim.x + threadIdx.x;
  int linear_thread_id = grid_level_thread_to_linear_thread_map[device_level_thread_id];
  int global_thread_id = linear_thread_id;
#ifdef USE_PARTITION_FOR_SHMEM_1
  if (threadIdx.x == 0) {
    hop_vertex = thread_to_src[global_thread_id];
    src_num_edges = csr->get_n_edges_for_vertex(hop_vertex);
    start_edge_idx = csr->get_start_edge_idx (hop_vertex);
  }

  __syncthreads();
#ifdef EDGES_IN_SHM_MEM
  const int SH_MEM_SZ = 1024*11;
  __shared__ VertexID sh_mem_edges[1024*11];
  __shared__ bool edges_in_shmem;
  if (threadIdx.x == 0)
    edges_in_shmem = (src_num_edges <= SH_MEM_SZ);
  __syncthreads ();

  if (edges_in_shmem) {
    for (int i = 0; i < src_num_edges; i += blockDim.x) {
      int j = i + threadIdx.x;
      if (j >= src_num_edges)
        continue;

      sh_mem_edges[j] = csr->get_edge(start_edge_idx+j);
    }

    __syncthreads();
  }
  
#endif
#endif
  if (linear_thread_id == -1)
    return;

#ifndef USE_PARTITION_FOR_SHMEM_1
  hop_vertex = thread_to_src[global_thread_id];
#endif
  VertexID root_vertex = thread_to_roots[global_thread_id];
  EdgePos_t start = vertex_sample_set_start_pos_fixed_size(root_partition, root_vertex);

#ifdef USE_PARTITION_FOR_SHMEM_1
  EdgePos_t n_edges = src_num_edges;//csr->get_n_edges_for_vertex(hop_vertex);
#else
  EdgePos_t n_edges = csr->get_n_edges_for_vertex(hop_vertex);
#endif

  if (n_edges > 0) {
    previous_stage_filled_range[linear_threads_executed+global_thread_id] = 1;
#ifdef EDGES_IN_SHM_MEM
    const CSR::Edge* src_edges = (edges_in_shmem) ? &sh_mem_edges[0] : csr->get_edges(hop_vertex);
#else
    const CSR::Edge* src_edges = csr->get_edges(hop_vertex);
#endif
    VertexID edge = next_random_walk(hop, hop_vertex, root_vertex, src_edges, 
    n_edges, (EdgePos_t)0, rand_num_gen, samplers[root_partition->get_vertex_idx(root_vertex)],
    csr);
    embeddings_additions[linear_threads_executed+global_thread_id] = edge;
  }
}

__global__ void run_hop_parallel_single_step_block_level_fixed_size_first_step (int N_HOPS, int hop, 
              CSRPartition* csr,
              CSRPartition* root_partition,
              VertexID* embeddings_additions, 
              EdgePos_t num_neighbors,
              EdgePos_t* previous_stage_filled_range,
              VertexID* thread_to_src,
              VertexID* thread_to_roots,
              EdgePos_t total_roots,
              const RandNumGen* rand_num_gen,
              Sampler* samplers)
{
  VertexID root_vertex = blockIdx.x*blockDim.x + threadIdx.x;
  if (root_vertex >= total_roots) 
    return;

  EdgePos_t start = vertex_sample_set_start_pos_fixed_size(root_partition, root_vertex);
  EdgePos_t start_edge_idx;
  start_edge_idx = csr->get_start_edge_idx (root_vertex);
  EdgePos_t n_edges = csr->get_n_edges_for_vertex(root_vertex);
  
  if (n_edges > 0) {
    previous_stage_filled_range[root_vertex] = 1;
    VertexID edge = next_random_walk(hop, root_vertex, root_vertex, csr->get_edges(root_vertex), 
    n_edges, (EdgePos_t)0, rand_num_gen, samplers[root_partition->get_vertex_idx(root_vertex)],
  csr);
    embeddings_additions[root_vertex] = edge;
  }
}

__global__ void run_hop_parallel_single_step_block_level_fixed_size (int N_HOPS, int hop, 
              CSRPartition* csr,
              CSRPartition* root_partition,
              VertexID* embeddings_additions, 
              EdgePos_t num_neighbors,
              EdgePos_t* previous_stage_filled_range,
              VertexID* thread_to_src,
              VertexID* thread_to_roots,
              EdgePos_t total_roots,
              EdgePos_t linear_threads_executed,
              const RandNumGen* rand_num_gen,
              Sampler* samplers)
{
  int linear_thread_id = blockIdx.x*blockDim.x + threadIdx.x;
  VertexID hop_vertex;
  __shared__ char sh_rand_num_gen_buf[sizeof(RandNumGen)]; 
  for (int v = 0; v < sizeof(RandNumGen)/blockDim.x + 1; v+= blockDim.x) {
    int i = v + threadIdx.x;
    if (i >= sizeof(RandNumGen))
      continue;
    sh_rand_num_gen_buf[i] = *(((char*)rand_num_gen) + i);
  }
  __syncthreads ();

  if (linear_thread_id >= total_roots) 
    return;

  const RandNumGen* sh_rand_num_gen = (RandNumGen*)&sh_rand_num_gen_buf[0];
  hop_vertex = thread_to_src[linear_thread_id];
  VertexID root_vertex = thread_to_roots[linear_thread_id];
  EdgePos_t start = vertex_sample_set_start_pos_fixed_size(root_partition, root_vertex);//map_orig_embedding_to_additions[2*(vertex - root_partition->first_vertex_id)];  
  //assert (map_orig_embedding_to_additions[2*(vertex - root_partition->first_vertex_id)] == vertex);
  EdgePos_t start_edge_idx;
  start_edge_idx = csr->get_start_edge_idx (hop_vertex);
  EdgePos_t n_edges = csr->get_n_edges_for_vertex(hop_vertex);
  
  if (n_edges > 0) {
    previous_stage_filled_range[linear_thread_id+linear_threads_executed] = 1;
    VertexID edge = next_random_walk(hop, hop_vertex, root_vertex, csr->get_edges(hop_vertex), 
    n_edges, (EdgePos_t)0, sh_rand_num_gen, samplers[root_partition->get_vertex_idx(root_vertex)],
    csr);
    embeddings_additions[linear_thread_id+linear_threads_executed] = edge;
  }
}