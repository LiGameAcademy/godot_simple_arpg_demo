extends HitDetectorBase
class_name ShapeHitDetector

## 引用场景中的 Area3D 或 CollisionShape3D 节点
## 用于定义攻击范围的形状和位置
@export var shape_node_path: NodePath

## 碰撞掩码 (如果不想用节点自带的 layer，可以在这里覆盖)
@export_flags_3d_physics var override_mask: int = 0

func _get_targets(caster: Node3D, _context: Dictionary = {}) -> Array[Node]:
    if not caster or shape_node_path.is_empty():
        return []
    
    # 1. 获取节点
    var shape_node = caster.get_node_or_null(shape_node_path)
    if not shape_node:
        push_warning("HitDetector: Shape node not found at %s" % shape_node_path)
        return []
    
    # 2. 提取形状 (Shape) 和 位置 (Transform)
    var shape_rid: RID
    var shape_transform: Transform3D = shape_node.global_transform
    
    # 兼容 Area3D 和 CollisionShape3D
    if shape_node is CollisionShape3D:
        shape_rid = shape_node.shape.get_rid()
    elif shape_node is Area3D:
        # Area3D 可能有多个形状，简单起见我们取第一个 CollisionShape3D 子节点
        # 或者你可以遍历所有子节点做多次查询
        var collision_shapes = shape_node.find_children("*", "CollisionShape3D", false)
        if collision_shapes.size() > 0:
            shape_rid = collision_shapes[0].shape.get_rid()
            shape_transform = collision_shapes[0].global_transform
        else:
            return []
            
    # 3. 构建查询 (直接使用物理服务器的底层API，性能最高)
    var space_state = caster.get_world_3d().direct_space_state
    var query = PhysicsShapeQueryParameters3D.new()
    
    query.shape_rid = shape_rid # 直接用 RID，比 new() 一个 Shape 更快且同步
    query.transform = shape_transform
    
    # 如果没覆盖掩码，就尝试读取 Area3D 的掩码，或者默认
    if override_mask != 0:
        query.collision_mask = override_mask
    elif shape_node is Area3D:
        query.collision_mask = shape_node.collision_mask
    else:
        query.collision_mask = 1 # 默认值
        
    query.collide_with_bodies = true
    query.collide_with_areas = true # 根据需求开关
    
    # 4. 执行查询
    var results = space_state.intersect_shape(query)
    var targets: Array[Node] = []
    
    for data in results:
        var collider = data["collider"]
        if collider != caster: # 排除自己
            targets.append(collider)
            
    return targets