using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraRotate : MonoBehaviour
{
    [SerializeField] private float roateSpeed;
    
    // Update is called once per frame
    void Update()
    {
        transform.Rotate(Vector3.up, roateSpeed * Time.deltaTime, Space.World);
    }
}
