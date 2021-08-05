/*
 * Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.
 *
 * NVIDIA CORPORATION and its licensors retain all intellectual property
 * and proprietary rights in and to this software, related documentation
 * and any modifications thereto.  Any use, reproduction, disclosure or
 * distribution of this software and related documentation without an express
 * license agreement from NVIDIA CORPORATION is strictly prohibited.
 *
 */

#include <components/wcc_graphs.hpp>
#include <utilities/test_utilities.hpp>

#include <cugraph/detail/utility_wrappers.hpp>
#include <cugraph/graph_functions.hpp>

#include <rmm/exec_policy.hpp>

#include <thrust/sort.h>

namespace cugraph {
namespace test {

template <typename vertex_t,
          typename edge_t,
          typename weight_t,
          bool store_transposed,
          bool multi_gpu>
std::tuple<cugraph::graph_t<vertex_t, edge_t, weight_t, store_transposed, multi_gpu>,
           std::optional<rmm::device_uvector<vertex_t>>>
LineGraph_Usecase::construct_graph(raft::handle_t const& handle,
                                   bool test_weighted,
                                   bool renumber) const
{
  uint64_t seed{0};

  edge_t num_edges = 2 * (num_vertices_ - 1);

  rmm::device_uvector<vertex_t> vertices_v(num_vertices_, handle.get_stream());
  rmm::device_uvector<vertex_t> src_v(num_edges, handle.get_stream());
  rmm::device_uvector<vertex_t> dst_v(num_edges, handle.get_stream());
  rmm::device_uvector<double> order_v(num_vertices_, handle.get_stream());

  thrust::sequence(
    rmm::exec_policy(handle.get_stream()), vertices_v.begin(), vertices_v.end(), vertex_t{0});

  cugraph::detail::uniform_random_fill(
    handle.get_stream_view(), order_v.data(), num_vertices_, double{0.0}, double{1.0}, seed);

  thrust::sort_by_key(
    rmm::exec_policy(handle.get_stream()), order_v.begin(), order_v.end(), vertices_v.begin());

  raft::copy(src_v.begin(), vertices_v.begin(), (num_vertices_ - 1), handle.get_stream());
  raft::copy(dst_v.begin(), vertices_v.begin() + 1, (num_vertices_ - 1), handle.get_stream());

  raft::copy(src_v.begin() + (num_vertices_ - 1),
             vertices_v.begin() + 1,
             (num_vertices_ - 1),
             handle.get_stream());
  raft::copy(dst_v.begin() + (num_vertices_ - 1),
             vertices_v.begin(),
             (num_vertices_ - 1),
             handle.get_stream());

  thrust::sequence(
    rmm::exec_policy(handle.get_stream()), vertices_v.begin(), vertices_v.end(), vertex_t{0});

  handle.get_stream_view().synchronize();

  return cugraph::
    create_graph_from_edgelist<vertex_t, edge_t, weight_t, store_transposed, multi_gpu>(
      handle,
      std::optional<std::tuple<vertex_t const*, vertex_t>>{
        std::make_tuple(vertices_v.data(), static_cast<vertex_t>(vertices_v.size()))},
      std::move(src_v),
      std::move(dst_v),
      std::nullopt,
      cugraph::graph_properties_t{true, false},
      false);
}

template std::tuple<cugraph::graph_t<int32_t, int32_t, float, false, false>,
                    std::optional<rmm::device_uvector<int32_t>>>
LineGraph_Usecase::construct_graph(raft::handle_t const&, bool, bool) const;

}  // namespace test
}  // namespace cugraph
