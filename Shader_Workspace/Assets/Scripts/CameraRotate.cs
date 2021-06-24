using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraRotate : MonoBehaviour
{
    [SerializeField] private float roateSpeed;
    
    // Update is called once per frame
    void Update()
    {
        transform.Rotate(transform.up, roateSpeed * Time.deltaTime, Space.Self);
    }
}
